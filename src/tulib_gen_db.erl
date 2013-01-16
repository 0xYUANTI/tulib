%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc BETA: A behaviour for simple, efficient, small databases.
%%% @reference http://birrell.org/andrew/papers/024-DatabasesPaper-SOSP.pdf
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
-module(tulib_gen_db).
-behaviour(gen_server).

%%%_* Exports ==========================================================
%% gen_db behaviour
-export([ behaviour_info/1
        ]).

%% gen_db API
-export([ close/1
        , delete/2
        , insert/2
        , lookup/2
        , new/2
        , open/2
        ]).

%% gen_server callbacks
-export([ code_change/3
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , init/1
        , terminate/2
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/assert.hrl").
-include_lib("tulib/include/logging.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * gen_db behaviour ------------------------------------------------
%% -callback do_delete(_, _) -> maybe(_, _).
%% -callback do_insert(_, _) -> maybe(_, _).
%% -callback do_lookup(_, _) -> maybe(_, _).
%% -callback init(_)         -> maybe(_, _).

behaviour_info(callbacks) ->
  [ {do_delete, 2}
  , {do_insert, 2}
  , {do_lookup, 2}
  , {init,      1}
  ];
behaviour_info(_) -> undefined.

%%%_ * gen_db API ------------------------------------------------------
close(Db)     -> call(Db, close).
delete(Db, A) -> call(Db, {do_delete, A}).
insert(Db, A) -> call(Db, {do_insert, A}).
lookup(Db, A) -> call(Db, {do_lookup, A}).


new(Db, Opts) ->
  case whereis(RegName = regname(Db)) of
    undefined ->
      {ok, _} = gen_server:start({local, RegName},
                                 ?MODULE,
                                 [{name, Db}|Opts],
                                 []),
      Db;
    _ -> erlang:error({registered, Db})
  end.

open(Db, Opts) -> new(Db, [{open,true}|Opts]).


call(Db, Op) ->
  case whereis(RegName = regname(Db)) of
    undefined -> erlang:error({not_registered, Db});
    _         -> gen_server:call(RegName, Op, infinity)
  end.

dirname(Db) -> ?a2l(Db).
regname(Db) -> tulib_atoms:catenate([gen_db_, Db]).

%%%_ * gen_server callbacks --------------------------------------------
-record(s, { mod   :: atom()
           , db    :: _
           , log   :: _
           , timer :: _
           }).

code_change(_, S, _) -> {ok, S}.

init(Opts) ->
  {ok, Name} = tulib_lists:assoc(name,       Opts),
  {ok, M}    = tulib_lists:assoc(mod,        Opts),
  {ok, Args} = tulib_lists:assoc(args,       Opts),
  DirName    = tulib_lists:assoc(dirname,    Opts, dirname(Name)),
  Open       = tulib_lists:assoc(open,       Opts, false),
  Checkpoint = tulib_lists:assoc(checkpoint, Opts, timer:minutes(1)),
  {Db, Log}  = do_init(M, Args, DirName, Open),
  {ok, TRef} = timer:send_interval(Checkpoint, checkpoint),
  {ok, #s{mod=M, db=Db, log=Log, timer=TRef}}.

terminate(_, #s{log=Log, timer=TRef}) ->
  tulib_dlogs:close(Log),
  {ok, cancel} = timer:cancel(TRef),
  ok.

handle_call({F, A} = Op, _, #s{mod=M, db=Db0, log=Log} = S)
  when F =:= do_delete
     ; F =:= do_insert ->
  case ?lift(M:F(Db0, A)) of
    {ok, Db} ->
      ?debug("~p = ~p(~p, ~p)", [Db, F, Db0, A]),
      tulib_dlogs:log(Log, Op),
      {reply, ok, S#s{db=Db}};
    {error, Rsn} = Err ->
      ?error("~p error: ~p", [F, Rsn]),
      {reply, Err, S}
  end;
handle_call({do_lookup, A}, _, #s{mod=M, db=Db} = S) ->
  {reply, ?lift(M:do_lookup(Db, A)), S};
handle_call(close, _, S) ->
  {stop, normal, ok, S}.

handle_cast(_Msg, S) -> {stop, bad_cast, S}.

handle_info(checkpoint, #s{db=Db, log=Log0} = S) ->
  ?info("checkpointing"),
  tulib_processes:flush(checkpoint),
  Log = checkpoint(Db, Log0),
  {noreply, S#s{log=Log}};
handle_info(Msg, S) ->
  ?warning("~p", [Msg]),
  {noreply, S}.

%%%_ * Internals -------------------------------------------------------
do_init(M, Args, DirName, Open) ->
  init_env(DirName),
  case Open of
    false -> do_new(M, Args);
    true  -> do_open(M)
  end.


%% $HOME/
%%       checkpoint.N
%%       logfile.N
%%       newVersion
%%       version
init_env(Home) ->
  put('$HOME', Home),
  tulib_sh:mkdir_p(Home).

checkpoint(N) -> filename:join(get('$HOME'), "checkpoint." ++ ?i2l(N)).
logfile(N)    -> filename:join(get('$HOME'), "logfile."    ++ ?i2l(N)).
newVersion()  -> filename:join(get('$HOME'), "newVersion").
version()     -> filename:join(get('$HOME'), "version").


do_new(M, Args) ->
  {ok, Db}  = M:init(Args),
  tulib_fs:write(checkpoint(0), Db),
  {ok, Log} = tulib_dlogs:open(logfile(0)),
  tulib_fs:write(version(), 0),
  {Db, Log}.


do_open(M) ->
  case filelib:is_file(newVersion()) of
    true  -> do_open(M, tulib_fs:read(newVersion()));
    false -> do_open(M, tulib_fs:read(version()))
  end.

do_open(M, Vsn) ->
  cleanup(Vsn - 1),
  Db0       = tulib_fs:read(checkpoint(Vsn)),
  {ok, Db}  = replay(Db0, logfile(Vsn), M),
  {ok, Log} = tulib_dlogs:open(logfile(Vsn)),
  {Db, Log}.

replay(Db0, Log, M) ->
  tulib_dlogs:foldterms(fun(Op, Db) -> do_replay(Op, Db, M) end, Db0, Log).

do_replay({F, A}, Db0, M) ->
  {ok, Db} = M:F(Db0, A),
  ?debug("~p = ~p(~p, ~p)", [Db, F, Db0, A]),
  Db.


checkpoint(Db, Log0) ->
  ?hence(filelib:is_file(version())),
  Vsn = tulib_fs:read(version()),
  tulib_fs:write(checkpoint(Vsn + 1), Db),
  tulib_dlogs:close(Log0),
  {ok, Log} = tulib_dlogs:open(logfile(Vsn + 1)),
  tulib_fs:write(newVersion(), Vsn + 1),
  cleanup(Vsn),
  Log.


cleanup(Vsn) ->
  tulib_sh:rm_rf(checkpoint(Vsn)),
  tulib_sh:rm_rf(logfile(Vsn)),
  [tulib_sh:mv(newVersion(), version()) || filelib:is_file(newVersion())].

%%%_* Tests ============================================================
-ifdef(TEST).

basic_test() ->
  with_test_db(fun(Db, Opts) ->
    ok          = insert(Db, foo),
    ok          = insert(Db, bar),
    {ok, true}  = lookup(Db, foo),
    {ok, true}  = lookup(Db, bar),
    ok          = delete(Db, foo),
    {ok, false} = lookup(Db, foo),
    {ok, true}  = lookup(Db, bar),

    ok          = close(Db),
    tulib_processes:sync_unregistered(regname(Db)),
    Db          = open(Db, Opts),

    {ok, false} = lookup(Db, foo),
    {ok, true}  = lookup(Db, bar),
    ok          = insert(Db, foo),
    {ok, true}  = lookup(Db, foo)
  end).

recovery_test() ->
  with_test_db([{checkpoint, 100}], fun(Db, Opts) ->
    ok         = insert(Db, foo),
    ok         = insert(Db, bar),

    timer:sleep(200), %checkpoint

    ok         = insert(Db, baz),
    ok         = insert(Db, quux),

    catch call(Db, crash),
    tulib_processes:sync_unregistered(regname(Db)),
    Db         = open(Db, Opts),

    {ok, true} = lookup(Db, foo),
    {ok, true} = lookup(Db, bar),
    {ok, true} = lookup(Db, baz),
    {ok, true} = lookup(Db, quux)
  end).

cberror_test() ->
  with_test_db(fun(Db, _Opts) ->
    {error, 42} = insert(Db, 42)
  end).

cover_test() ->
  with_test_db(fun(Db, Opts) ->
    catch new(test_db, Opts),
    catch insert(my_db, foo),
    regname(Db) ! info,
    gen_server:cast(regname(Db), cast),
    {ok, bar} = code_change(foo, bar, baz),
    _ = behaviour_info(callbacks),
    _ = behaviour_info(foo)
  end).


%% Helper
with_test_db(Fun) ->
  with_test_db([], Fun).
with_test_db(Opts0, Fun) ->
  Dir  = tulib_sh:mktemp_d("__with_test_db__"),
  Opts = [ {mod,     test_db}
         , {args,    []}
         , {dirname, Dir}
         ] ++ Opts0,
  Db   = new(test_db, Opts),
  try
    Fun(Db, Opts)
  after
    catch close(Db),
    tulib_processes:sync_unregistered(regname(Db)),
    tulib_sh:rm_rf(Dir)
  end.

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
