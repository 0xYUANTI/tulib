%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc BETA: Generic lock manager.
%%% @todo deadlock detection
%%% @copyright 2012 Klarna AB
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
-module(tulib_gen_lock).
-behaviour(gen_server).

%%%_* Exports ==========================================================
%% API
-export([ with_lock/4
        , start/0
        , start/1
        , start_link/0
        , start_link/1
        , stop/1
        ]).

%% gen_server callbacks
-export([ code_change/3
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , init/1
        , terminate/2
        ]).

-export_type([ lock/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/logging.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * Types -----------------------------------------------------------
-record(s,
        { q=dict:new()    :: dict:dict(lock(), queue:queue(from()))
        , held=dict:new() :: dict:dict(pid(), {lock(), reference()})
        }).

-type lock() :: _.
-type from() :: {pid(), reference()}.

%%%_ * API -------------------------------------------------------------
-spec with_lock(Locker::atom() | pid(),
                lock(),
                fun(() -> A), timeout()) -> maybe(A, _).
%% @doc Execute Thunk while holding Lock. Thunk gets Timeout ms to run.
with_lock(Locker, Lock, Thunk, Timeout) ->
  try
    ok = acquire(Locker, Lock),
    case
      tulib_par:eval(fun(Thunk) -> Thunk() end,
                     [Thunk],
                     [{errors, true}],
                     Timeout)
    of
      {ok, [Ret]}            -> Ret;
      {error, timeout} = Err -> Err
    end
  after
    _ = release(Locker, Lock)
  end.

acquire(Locker, Lock) -> gen_server:call(Locker, {acquire, Lock}, infinity).
release(Locker, Lock) -> gen_server:call(Locker, {release, Lock}, infinity).

start()          -> gen_server:start(?MODULE, [], []).
start(Name)      -> gen_server:start({local, Name}, ?MODULE, [], []).
start_link()     -> gen_server:start_link(?MODULE, [], []).
start_link(Name) -> gen_server:start_link({local, Name}, ?MODULE, [], []).
stop(Locker)     -> gen_server:call(Locker, stop, infinity).

%%%_ * gen_server callbacks --------------------------------------------
init([])             -> {ok, #s{}}.
terminate(_, _)      -> ok.
code_change(_, S, _) -> {ok, S}.

handle_call({acquire, Lock}, {_Pid, _Ref} = From, S0) ->
  case do_acquire(Lock, From, S0) of
    {ok, S}    ->
      ?debug("~p: grant: ~p", [_Pid, Lock]),
      {reply, ok, S};
    {error, S} ->
      ?debug("~p: block: ~p", [_Pid, Lock]),
      {noreply, S}
  end;
handle_call({release, Lock}, {_Pid, _Ref} = From, S0) ->
  ?debug("~p: release: ~p", [_Pid, Lock]),
  {reply, ok, do_release(Lock, From, S0)};
handle_call(stop, _, S) ->
  {stop, normal, ok, S}.

handle_cast(_Msg, S) -> {stop, bad_cast, S}.

handle_info({'DOWN', _Ref, process, Pid, Rsn}, S) ->
  ?error("DOWN: ~p: ~p", [Pid, Rsn]),
  {noreply, do_down(Pid, S)};
handle_info(Msg, S) ->
  ?warning("~p", [Msg]),
  {noreply, S}.

%%%_ * Internals -------------------------------------------------------
-spec do_acquire(lock(), from(), #s{}) -> #s{}.
%% @doc Attempt to acquire Lock for From.
do_acquire(Lock, {Pid, _Ref} = From, #s{q=Q0, held=Held0} = S) ->
  case do_acquire_q(Lock, From, Q0) of
    {[From], Q} -> {ok,    S#s{q=Q, held=do_acquire_held(Lock, Pid, Held0)}};
    {[],     Q} -> {error, S#s{q=Q}}
  end.

do_acquire_q(Lock, From, Q) ->
  case dict:find(Lock, Q) of
    {ok, Queue} -> {[],     dict:store(Lock, queue:snoc(Queue, From), Q)};
    error       -> {[From], dict:store(Lock, queue:from_list([From]), Q)}
  end.

do_acquire_held(Lock, Pid, Held) ->
  error  = dict:find(Pid, Held),
  MonRef = erlang:monitor(process, Pid),
  dict:store(Pid, {Lock, MonRef}, Held).

-spec do_release(lock(), from(), #s{}) -> #s{}.
%% @doc Release Lock for From.
do_release(Lock, {Pid, _Ref}, #s{q=Q0, held=Held0} = S) ->
  Held = do_release_held(Lock, Pid, Held0),
  case do_release_q(Lock, Pid, Q0) of
    {[], Q} ->
      S#s{q=Q, held=Held};
    {[{NextPid, _NextRef} = Next], Q} ->
      ?debug("~p: grant: ~p", [Pid, Lock]),
      gen_server:reply(Next, ok),
      S#s{q=Q, held=do_acquire_held(Lock, NextPid, Held)}
  end.

do_release_held(Lock, Pid, Held) ->
  {ok, {Lock, MonRef}} = dict:find(Pid, Held),
  true                 = erlang:demonitor(MonRef, [flush]),
  dict:erase(Pid, Held).

do_release_q(Lock, Pid, Q) ->
  {ok, Queue0} = dict:find(Lock, Q),
  {Pid, _Ref}  = queue:head(Queue0),
  Queue        = queue:tail(Queue0),
  case queue:peek(Queue) of
    empty         -> {[],     dict:erase(Lock, Q)};
    {value, Next} -> {[Next], dict:store(Lock, Queue, Q)}
  end.

-spec do_down(pid(), #s{}) -> #s{}.
%% @doc Force-release lock held by Pid.
do_down(Pid, #s{held=Held} = S) ->
  {ok, {Lock, _MonRef}} = dict:find(Pid, Held),
  ?debug("~p: release: ~p", [Pid, Lock]),
  do_release(Lock, {Pid, undefined}, S).

%%%_* Tests ============================================================
-ifdef(TEST).

basic_test() ->
  {ok, Locker} = start(),
  spawn(?thunk(
    {ok, 42} = with_lock(Locker, foo, ?thunk(timer:sleep(1), 42), 10))),
  spawn(?thunk(
    {ok, 42} = with_lock(Locker, foo, ?thunk(timer:sleep(1), 42), 10))),
  ok = timer:sleep(20),
  ok = stop(Locker).

error_test() ->
  {ok, Locker} = start(),
  {error, {lifted_exn, exn, _}} =
    with_lock(Locker, bar, ?thunk(throw(exn)), 10),
  {error, foo} =
    with_lock(Locker, bar, ?thunk({error, foo}), 10),
  ok = stop(Locker).

timeout_test() ->
  {ok, Locker} = start(),
  {error, timeout} = with_lock(Locker, baz, ?thunk(timer:sleep(10)), 5),
  ok = stop(Locker).

down_test() ->
  {ok, Locker} = start(),
  Pid = spawn(?thunk(with_lock(Locker, quux, ?thunk(timer:sleep(10)), 20))),
  timer:sleep(5),
  true = tulib_processes:kill(Pid),
  {ok, ok} = with_lock(Locker, quux, ?thunk(ok), 20),
  ok = stop(Locker).

cover_test() ->
  {ok, Pid} = start(locker1),
  {ok, _}   = start_link(locker2),
  {ok, _}   = start_link(),
  {ok, bar} = code_change(foo, bar, baz),
  gen_server:cast(Pid, msg),
  locker2 ! msg,
  timer:sleep(100),
  ok.

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
