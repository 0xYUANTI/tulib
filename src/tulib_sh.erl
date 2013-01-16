%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Safe and convenient procedures for interacting with Unix.
%%% All functions assert success internally and aim to return something that's
%%% useful in a pipeline.
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
-module(tulib_sh).

%%%_* Exports ==========================================================
-export([ cp/2
        , eval/1
        , eval/2
        , host/1
        , ls/1
        , mkdir/1
        , mkdir_p/1
        , mktemp/0
        , mktemp/1
        , mktemp/2
        , mktemp_d/0
        , mktemp_d/1
        , mktemp_d/2
        , mktemp_u/0
        , mktemp_u/1
        , mktemp_u/2
        , mv/2
        , rm_rf/1
        , rmdir/1
        , touch/1
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").
-include_lib("kernel/include/inet.hrl").
-include_lib("tulib/include/assert.hrl").
-include_lib("tulib/include/guards.hrl").
-include_lib("tulib/include/logging.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
-spec cp(string(), string()) -> string().
%% @doc Copy Src to Dest. Return Dest.
cp(Src, Dest) ->
  {ok, _} = file:copy(Src, Dest),
  Dest.

cp_test() ->
  File       = mktemp_u(),
  {error, _} = ?lift(cp(File, File ++ "2")),
  {ok, _}    = tulib_fs:with_temp_file(fun(F) -> cp(F, F ++ "2") end).


-spec eval(string()) -> maybe(string(), {non_neg_integer(), string()}).
%% @doc Evaluate Cmd via os:cmd/1. Return Cmd's output or Cmd's exit
%% code along with it's output, if the exit code is =/= 0.
eval(Cmd) ->
  tulib_fs:with_temp_file(fun(File) ->
    Status0        = os:cmd(tulib_strings:fmt("~s > ~s 2>&1; echo $?",
                                              [Cmd, File])),
    {Status, "\n"} = string:to_integer(Status0),
    {ok, Output0}  = file:read_file(File),
    Output         = ?b2l(Output0),
    case Status of
      0 -> {ok, Output};
      N -> {error, {N, Output}}
    end
  end).

eval1_test() ->
  File            = mktemp_u(),
  {error, {_, _}} = eval("ls " ++ File),
  {ok, _}         = tulib_fs:with_temp_file(fun(F) -> eval("ls " ++ F) end).


-spec eval(string(), string()) -> maybe(string(), _).
%% @doc Pipe Stdin into Cmd.
eval(Stdin, Cmd) ->
  tulib_fs:with_temp_file(fun(File) ->
    ok = file:write_file(File, Stdin),
    eval("cat " ++ File ++ " | " ++ Cmd)
  end).

eval2_test() ->
  {ok, "foo"} = eval("foo", "cat").


-spec host(string() | inet:ip_address()) -> inet:ip_address() | string().
%% @doc Return the IP address associated with a hostname or the hostname
%% associated with an IP address.
host(Host) when ?is_string(Host) ->
  {ok, Addr} = inet:getaddr(Host, inet),
  Addr;
host(IP) when ?is_ip_address(IP) ->
  {ok, Hostent} = inet:gethostbyaddr(IP),
  tulib_lists:to_list(Hostent#hostent.h_name).

host_test() ->
  {127,0,0,1} = host("localhost"),
  "localhost" = host({127,0,0,1}).

-spec ls(string()) -> [string()].
%% @doc Return a list of the filenames in Dir.
ls(Dir) ->
  {ok, Files} = file:list_dir(Dir),
  Files.

ls_test() -> [_|_] = ls("/tmp").


-spec mkdir(string()) -> string().
%% @doc Create the directory Dir. Return Dir.
mkdir(Dir) ->
  ok = file:make_dir(Dir),
  Dir.

mkdir_test() ->
  Dir = mktemp_u("mkdir_test", ""),
  rmdir(mkdir("/tmp/" ++ Dir)).

-spec mkdir_p(string()) -> string().
%% @doc Create the directory Dir and any necessary parent directories.
%% Return Dir.
mkdir_p(Dir) ->
  ok = filelib:ensure_dir(Dir),
  filelib:is_dir(Dir) orelse (ok = file:make_dir(Dir)),
  Dir.

mkdir_p_test() ->
  Dir = mktemp_u(),
  rmdir(mkdir_p("/tmp/" ++ Dir ++ "/" ++ Dir)).


-spec mktemp() -> string().
%% @doc Create a file with a name that is probably unique. Return the
%% filename. The `exclusive' option should be supplied when opening this
%% filename.
%% The two optional arguments are
%%   Prefix: the stem of the returned filename (defaults to mktemp)
%%   Dir: the directory in which to create the file (defaults to /tmp)
mktemp() ->
  mktemp(mktemp).
mktemp(Prefix) ->
  mktemp(Prefix, "/tmp").
mktemp(Prefix, Dir) ->
  File     = temp_name(Dir, Prefix),
  {ok, FD} = file:open(File, [write, exclusive]),
  ok       = file:close(FD),
  File.

mktemp_test() ->
  "/tmp/mktemp" ++ [_|_] = F1 = mktemp(),
  "/tmp/"       ++ [_|_] = F2 = mktemp("", "/tmp"),
  rm_rf(F1),
  rm_rf(F2).

-spec mktemp_u() -> string().
%% @doc Unsafe mktemp. Returns a filename which is probably unique, but
%% does not actually create the file.
mktemp_u()            -> mktemp_u(mktemp).
mktemp_u(Prefix)      -> mktemp_u(Prefix, "/tmp").
mktemp_u(Prefix, Dir) -> temp_name(Dir, Prefix).

mktemp_u_test() -> "/tmp/mktemp" ++ _ = mktemp_u().

-spec mktemp_d() -> string().
%% @doc Create a unique directory and return its name.
mktemp_d() ->
  mktemp_d(mktemp).
mktemp_d(Prefix) ->
  mktemp_d(Prefix, "/tmp").
mktemp_d(Prefix, Dir) ->
  TmpDir = temp_name(Dir, Prefix),
  ok     = file:make_dir(TmpDir),
  TmpDir.

mktemp_d_test() -> rmdir(mktemp_d()).

%% Helpers
temp_name(Dir, "") ->
  temp_name(Dir ++ "/");
temp_name(Dir, Prefix) ->
  temp_name(filename:join(tulib_lists:to_list(Dir),
                          tulib_lists:to_list(Prefix))).

temp_name(Stem) -> Stem ++ integer_to_list(crypto:rand_uniform(0, 1 bsl 127)).

temp_name_test() ->
  "/tmp/prefix" ++ N = temp_name("/tmp", "prefix"),
  list_to_integer(N).


-spec mv(string(), string()) -> string().
%% @doc Rename OldPath to NewPath. Return NewPath.
mv(OldPath, NewPath) ->
  ok = file:rename(OldPath, NewPath),
  NewPath.

mv_test() ->
  {ok, _} = tulib_fs:with_temp_file(fun(F) -> mv(F, F ++ "2") end).


-spec rm_rf(string()) -> string().
%% @doc Recursively remove everything under Path.
rm_rf(Path) ->
  case filelib:is_dir(Path) of
    true ->
      [rm_rf(filename:join(Path, File)) || File <- ls(Path)],
      ok = file:del_dir(Path);
    false ->
      case file:delete(Path) of
        ok              -> ok;
        {error, enoent} -> ok
      end
  end,
  Path.

rm_rf_test() -> rm_rf(mktemp_d()).


-spec rmdir(string()) -> string().
%% @doc Remove Dir. Return Dir.
rmdir(Dir) ->
  ok = file:del_dir(Dir),
  Dir.


-spec touch(string()) -> string().
%% @doc Update File's ctime. Return File.
touch(File) ->
  ok = file:change_time(File, calendar:now_to_datetime(now())),
  File.

-ifdef(NOJENKINS).
touch_test() ->
  {ok, _} = tulib_fs:with_temp_file(fun(File) ->
    {ok, #file_info{mtime=Mtime1}} = file:read_file_info(File),
    touch(File),
    {ok, #file_info{mtime=Mtime2}} = file:read_file_info(File),
    true                           = Mtime1 < Mtime2
  end).
-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
