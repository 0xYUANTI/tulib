%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Filesystem-related utility functions.
%%% @copyright 2011 Klarna AB
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%
%%%   Copyright 2011-2013 Klarna AB
%%%
%%%   Licensed under the Apache License, Version 2.0 (the "License");
%%%   you may not use this file except in compliance with the License.
%%%   You may obtain a copy of the License at
%%%
%%%       http://www.apache.org/licenses/LICENSE-2.0
%%%
%%%   Unless required by applicable law or agreed to in writing, software
%%%   distributed under the License is distributed on an "AS IS" BASIS,
%%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%%   See the License for the specific language governing permissions and
%%%   limitations under the License.
%%%

%%%_* Module declaration ===============================================
-module(tulib_fs).

%%%_* Exports ==========================================================
-export([ read/1
        , with_fd/2
        , with_fds/2
        , with_temp_file/1
        , with_temp_file/2
        , with_temp_files/2
        , with_temp_fd/1
        , with_temp_fd/2
        , with_temp_fds/2
        , write/2
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * read/write ------------------------------------------------------
-spec read(file()) -> _ | undefined.
%% @doc Read an Erlang term from File.
read(File) ->
  case file:read_file(File) of
    {ok, Bin}       -> ?b2t(Bin);
    {error, enoent} -> undefined
  end.

-spec write(file(), Term) -> Term.
%% @doc Write an Erlang term to File.
write(File, Term) ->
  ok = file:write_file(File, ?t2b(Term)),
  Term.

read_write_test() ->
  with_temp_file(fun(File) ->
    foo = write(File, foo),
    foo = read(File)
  end),
  undefined = read(tulib_sh:mktemp_u("__read_write_test__")),
  ok.

%%%_ * FDs -------------------------------------------------------------
-spec with_fd(file(), fun((file:io_device()) -> A)) -> maybe(A, _).
%% @doc Apply F to a file descriptor pointing to File.
with_fd(File, F) ->
  tulib_maybe:lift_with(
    file:open(File, [read, write]),
    F,
    fun file:close/1).

with_fd_test() ->
  with_temp_file(fun(File) ->
    {ok, ok}    = with_fd(File, fun(FD) -> file:write(FD, <<"foo">>) end),
    {ok, "foo"} = with_fd(File, fun(FD) -> file:read(FD, 3) end)
  end).


-spec with_fds([file()], fun(([file:io_device()]) -> A)) -> maybe(A, _).
%% @doc Apply F to a list of file descriptors pointing to Files.
with_fds(Files, F) -> tulib_call:unwind_with(fun with_fd/2, Files, F).

with_fds_test() ->
  with_temp_files(2, fun([File1, File2]) ->
    {ok, ok} =
      with_fds([File1, File2], fun([FD1, FD2]) ->
        file:write(FD1, <<"foo">>),
        file:write(FD2, <<"bar">>)
      end),
    {ok, ["foo", "bar"]}  =
      with_fds([File1, File2], fun([FD1, FD2]) ->
        [ ?unlift(file:read(FD1, 3))
        , ?unlift(file:read(FD2, 3))
        ]
      end)
  end).

with_fds_error_test() ->
  with_temp_files(2, fun([File1, File2]) ->
    ok              = file:change_mode(File2, 8#00000),
    {error, eacces} = with_fds([File1, File2], fun(_) -> ok end)
  end).

-spec with_temp_fd(fun(({file(), file:io_device()}) -> A)) -> maybe(A, _).
%% @doc Apply F to a two-tuple: the name of a temporary file and a file
%% descriptor pointing to that file.
with_temp_fd(F) ->
  with_temp_fd(with_temp_fd, F).
with_temp_fd(Prefix, F) ->
  File = tulib_sh:mktemp_u(Prefix),
  tulib_maybe:lift_with(
    file:open(File, [read, write, exclusive]),
    fun(FD) -> F({File, FD}) end,
    fun(FD) -> ok = file:close(FD), ok = file:delete(File) end).

with_temp_fd_test() ->
  {ok, ok} = with_temp_fd(fun({_, FD}) -> file:write(FD, <<"foo">>) end).


-spec with_temp_fds(pos_integer() | [file()], fun(([{file(), file:io_device()}]) -> A)) -> A.
%% @doc Apply F to a list of N two-tuples (c.f. with_temp_fd/1,2).
with_temp_fds(N, F) when is_integer(N) ->
  with_temp_fds(lists:duplicate(N, with_temp_fd), F);
with_temp_fds(Prefixes, F) when is_list(Prefixes) ->
  tulib_call:unwind_with(fun with_temp_fd/2, Prefixes, F).

with_temp_fds_test() ->
  {ok, {"foo", "bar"}} =
    with_temp_fds(2, fun([{File1, FD1}, {File2, FD2}]) ->
      file:write(FD1, "foo"),
      file:close(FD1),
      {ok, FD1_} = file:open(File1, [read]),
      Ret1       = ?unlift(file:read(FD1_, 3)),

      file:write(FD2, "bar"),
      file:close(FD2),
      {ok, FD2_} = file:open(File2, [read]),
      Ret2       = ?unlift(file:read(FD2_, 3)),

      {Ret1, Ret2}
    end).

%%%_ * Files -----------------------------------------------------------
-spec with_temp_file(fun((file()) -> A)) -> maybe(A, _).
%% @doc Apply F to the name of a temporary file.
with_temp_file(F) ->
  with_temp_file(with_temp_file, F).
with_temp_file(Prefix, F) ->
  tulib_maybe:lift_with(
    tulib_sh:mktemp(Prefix),
    F,
    fun file:delete/1).


-spec with_temp_files([file()], fun(([file()]) -> A)) -> maybe(A, _).
%% @doc Apply F to a list of names of temporary files.
with_temp_files(N, F) when is_integer(N) ->
  with_temp_files(lists:duplicate(N, with_temp_file), F);
with_temp_files(Prefixes, F) when is_list(Prefixes) ->
  tulib_call:unwind_with(fun with_temp_file/2, Prefixes, F).

with_temp_files_test() ->
  {ok, ok} =
    with_temp_files([t1, t2], fun([F1, F2]) ->
      {ok, _} = file:open(F1, [write]),
      {ok, _} = file:open(F2, [write]),
      ok
    end).

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
