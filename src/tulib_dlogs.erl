%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Simplified interface to disk_log.
%%% @todo test badbytes
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
-module(tulib_dlogs).

%%%_* Exports ==========================================================
%% Open/close
-export([ close/1
        , open/1
        , popen/1
        , with_dlog/2
        , wopen/1
        ]).

%% Primitives
-export([ bump/1
        , file/1
        , log/2
        , peek/1
        , sync/1
        ]).

%% Traversal
-export([ eachchunk/2
        , eachterm/2
        , foldchunks/3
        , foldterms/3
        , traverse/3
        ]).

%% Iterators
-export([ chunk/1
        , iterator/1
        , step/1
        ]).

-export_type([ dlog/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/guards.hrl").
-include_lib("tulib/include/logging.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * Private constructor ---------------------------------------------
-record(dl, {og::_}).
-opaque dlog() :: #dl{}.

dlog(DiskLog) -> tulib_maybe:lift_with(DiskLog, fun lift/1).
lift(Log)     -> #dl{og=Log}.

%%%_ * Open/close ------------------------------------------------------
-spec open(file()) -> maybe(dlog(), _).
%% @doc Open File as a read/write disk_log.
open(File) -> do_open([ {file, File}
                      , {name, ?l2a(File)}
                      , {mode, read_write}
                      , {type, halt}
                      | opts()
                      ]).

-spec popen(file()) -> maybe(dlog(), _).
%% @doc Open File as a read-only disk_log. Multiple processes may popen/1 the
%% same File concurrently.
popen(File) -> do_open([ {file, File}
                       , {name, {?l2a(File), self()}}
                       , {mode, read_only}
                       , {type, halt}
                       | opts()
                       ]).

-spec wopen(file()) -> maybe(dlog(), _).
%% @doc Open File as a wrap disk_log.
%% @todo size is currently fixed
wopen(File) -> do_open([ {file, File}
                       , {name, ?l2a(File)}
                       , {mode, read_write}
                       , {type, wrap}
                       , {size, {100 * 1000 * 1000, 100}}
                       | opts()
                       ]).

%% Shared options.
opts() ->
  [ {format, internal}
  , {repair, true}
  ].

%% Prim open: check for file corruption.
do_open(Opts) ->
  dlog(do_open1(Opts)).
do_open1(Opts) ->
  case disk_log:open(Opts) of
    {ok, Log}                                      -> {ok, Log};
    {repaired, Log, {recovered, _}, {badbytes, 0}} -> {ok, Log};
    {repaired, _,   {recovered, _}, {badbytes, _}} -> {error, badbytes};
    {error, _} = Err                               -> Err
  end.


-spec close(dlog()) -> ok.
%% @doc Close Log. Sync before closing.
close(#dl{og=Log}) ->
  case ?unlift(tulib_lists:assoc(mode, disk_log:info(Log))) of
    read_only  -> ok;
    read_write -> ok = disk_log:sync(Log)
  end,
  ok = disk_log:close(Log).


-spec with_dlog(file(), fun((dlog()) ->  A)) -> maybe(A, _).
%% @doc Open File as a dlog, apply F to this dlog, then close it.
with_dlog(File, F) -> tulib_maybe:lift_with(open(File), F, fun close/1).

%%%_ * Primitives ------------------------------------------------------
-spec bump(dlog()) -> ok.
%% @doc Start a new wrap-log file.
bump(#dl{og=Log}) -> ok = disk_log:inc_wrap_file(Log).

-spec file(dlog()) -> file().
%% @doc Return the name of the file associated with Log.
file(#dl{og=Log}) -> ?unlift(tulib_lists:assoc(file, disk_log:info(Log))).

-spec log(dlog(), _) -> ok.
%% @doc Append Term to Log.
log(#dl{og=Log}, Term) -> ok = disk_log:blog(Log, ?t2b(Term)).

-spec peek(file()) -> maybe(_, empty).
%% @doc Return the term at the beginning of File.
peek(File) ->
  with_dlog(File, fun(#dl{og=Log}) ->
    case disk_log:chunk(Log, start, 1) of
      {error, _} = Err -> Err;
      {_Cont, [Term]}  -> {ok, Term};
      {_Cont, [], BB}  -> {error, {badbytes, BB}};
      eof              -> {error, empty}
    end
  end).

-spec sync(dlog()) -> ok.
%% @doc Sync Log to disk.
sync(#dl{og=Log}) -> ok = disk_log:sync(Log).

%%%_ * Traversal -------------------------------------------------------
-spec traverse(fun((_, A) -> {next, A} | {done, A}),
               A,
               file()) -> maybe(A, _).
%% @doc Generic disk_log iterator.
traverse(F, Acc0, File) when ?is_string(File) ->
  traverse(F, Acc0, [File]);
traverse(F, Acc0, [File|_] = Files) when ?is_string(File) ->
  tulib_maybe:reduce(
    fun(File, Acc) ->
      traverse1(F, Acc, File)
    end, Acc0, Files).


traverse1(F, Acc0, File) ->
  {ok, #dl{og=Log}} = popen(File),
  try traverse1(disk_log:chunk(Log, start), F, Acc0, Log)
  catch _:Exn -> {error, Exn}
  after disk_log:close(Log)
  end.

traverse1({error, _} = Err, _F, _Acc, _Log) ->
  Err;
traverse1({Cont, Terms}, F, Acc0, Log) ->
  case F(Terms, Acc0) of
    {next, Acc} -> traverse1(disk_log:chunk(Log, Cont), F, Acc, Log);
    {done, Acc} -> {ok, Acc}
  end;
traverse1({_, _, BB}, _F, _Acc, _Log) ->
  {error, {badbytes, BB}};
traverse1(eof, _F,  Acc, _Log) ->
  {ok, Acc}.


-spec eachchunk(fun(), file()) -> ok.
%% @doc Apply F to each chunk in File.
eachchunk(F, File) ->
  {ok, _} = traverse(fun(Terms, _) -> {next, F(Terms)} end, undefined, File),
  ok.

-spec eachterm(fun(), file()) -> ok.
%% @doc Apply F to each term in File.
eachterm(F, File) ->
  eachchunk(fun(Terms) -> lists:foreach(F, Terms) end, File).


-spec foldchunks(fun((_, A) -> A), A, file()) -> maybe(A, _).
%% @doc Reduce the chunks in File to Acc0 via F.
foldchunks(F, Acc0, File) ->
  traverse(fun(Terms, Acc) -> {next, F(Terms, Acc)} end, Acc0, File).

-spec foldterms(fun((_, A) -> A), A, file()) -> maybe(A, _).
%% @doc Reduce the terms in File to Acc0 via F.
foldterms(F, Acc0, File) ->
  foldchunks(
    fun(Terms, Acc1) ->
      lists:foldl(fun(Term, Acc) -> F(Term, Acc) end, Acc1, Terms)
    end, Acc0, File).

%%%_ * Iterators -------------------------------------------------------
-record(iterator,
        { log
        , cont=start
        , chunk={error, start}
        }).

-type chunk_error() :: start
                     | eof
                     | {badbytes, integer()}
                     | _.

-opaque iterator() :: #iterator{}.

-spec iterator(dlog()) -> iterator().
%% @doc Return a chunk-iterator for Dlog.
iterator(Dlog) -> #iterator{log=Dlog#dl.og}.

-spec step(iterator()) -> iterator().
%% @doc Advance I by one.
step(#iterator{log=Log, cont=Cont0} = I) ->
  case disk_log:chunk(Log, Cont0) of
    {error, _} = Err    -> I#iterator{chunk=Err};
    {Cont, Terms}       -> I#iterator{cont=Cont, chunk={ok, Terms}};
    {_Cont, _Terms, BB} -> I#iterator{chunk={error, {badbytes, BB}}};
    eof                 -> I#iterator{chunk={error, eof}}
  end.

-spec chunk(iterator())   -> maybe(_, chunk_error()).
%% @doc Return the current chunk.
chunk(#iterator{chunk=C}) -> C.

%%%_* Tests ============================================================
-ifdef(TEST).

basic_test() ->
  File    = tulib_sh:mktemp_u(),
  {ok, _} = with_dlog(File, fun(Log) ->
    File        = file(Log),
    {ok, RoLog} = popen(File),
    close(RoLog),
    log(Log, foo),
    log(Log, bar),
    sync(Log)
  end),
  {ok, [bar, foo]} = foldterms(fun tulib_lists:cons/2, [], File),
  tulib_sh:rm_rf(File).

peek_test() ->
  File           = tulib_sh:mktemp_u(),

  {ok, Log}      = open(File),
  close(Log),
  {error, empty} = peek(File),

  {ok, Log2}     = open(File),
  log(Log2, foo),
  close(Log2),
  {ok, foo}      = peek(File),

  tulib_sh:rm_rf(File),
  ok.

wrap_test() ->
  File             = tulib_sh:mktemp_u(),
  {ok, Log}        = wopen(File),
  log(Log, foo),
  bump(Log),
  log(Log, bar),
  sync(Log),
  {ok, Files0}     = tulib_sh:eval("ls " ++ File ++ "*"),
  Files            = string:tokens(Files0, "\n"),
  {ok, [bar, foo]} = foldterms(fun tulib_lists:cons/2,
                               [],
                               tulib_lists:take(2, Files)),
  {ok, _}          = tulib_sh:eval("rm " ++ File ++ "*"),
  ok.

traverse_test() ->
  File1 = tulib_sh:mktemp_u(),
  File2 = tulib_sh:mktemp_u(),

  {ok, Log1} = open(File1),
  log(Log1, foo),
  log(Log1, bar),
  close(Log1),

  {ok, Log2} = open(File2),
  log(Log2, baz),
  log(Log2, quux),
  close(Log2),

  {ok, [foo, bar, baz, quux]} =
    foldchunks(tulib_combinators:flip(fun lists:append/2),
               [],
               [File1, File2]),
  {ok, [quux, baz, bar, foo]} =
    foldterms(fun tulib_lists:cons/2, [], [File1, File2]),
  ok = eachterm(fun(_) -> ok end, [File1, File2]),
  {ok, snarf} =
    traverse(fun(Terms, '') ->
               case lists:member(baz, Terms) of
                 true  -> {done, snarf};
                 false -> {next, ''}
               end
             end, '', [File1, File2]),

  tulib_sh:rm_rf(File1),
  tulib_sh:rm_rf(File2).

iterator_test() ->
  File           = tulib_sh:mktemp_u(),
  Chunk1         = <<42:(64*1000*8)>>,
  Chunk2         = <<23:(64*1000*8)>>,

  {ok, Log}      = open(File),
  log(Log, Chunk1),
  log(Log, Chunk2),
  close(Log),
  {ok, Log_}     = open(File),

  I0             = iterator(Log_),
  {error, start} = chunk(I0),
  I1             = step(I0),
  {ok, _}        = chunk(I1),
  I2             = step(I1),
  {ok, _}        = chunk(I2),
  I3             = step(I2),
  {error, eof}   = chunk(I3),

  tulib_sh:rm_rf(File).

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
