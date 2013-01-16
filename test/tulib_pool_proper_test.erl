%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc proper test(s) for tulib_pool
%%%
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
-module(tulib_pool_proper_test).

-ifdef(TEST).
-ifdef(PROPER).

-behaviour(proper_statem).
-behaviour(gen_server).

%%%_* Exports ==========================================================
-export([ prop_sequential/0
        , run/2
        , run_timeout/3
        , run_async/2
        , run_async_timeout/3
        , run_async_not_alive/3
        , run_async_wait/2
        , run_async_wait_timeout/3
        , flush/1
        ]).

-export([ initial_state/0
        , command/1
        , precondition/2
        , postcondition/3
        , next_state/3
        ]).

-export([ init/1
        , terminate/2
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , code_change/3
        ]).

%%%_* Includes =========================================================
-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/logging.hrl").

%%%_* Code =============================================================
%%%_ * Types -----------------------------------------------------------
-record(s, {pid, v}).

-define(commands, 100).
sequential_test() ->
  ?assert(proper:quickcheck(
            tulib_pool_proper_test:prop_sequential(), ?commands)).


prop_sequential() ->
  ?FORALL(Cmds, commands(?MODULE),
          ?TRAPEXIT(
             begin
               {ok, Pid1} = start_link(),
               {ok, Pid2} = tulib_pool:start_link({local, tulib_pool},
                                                  start_pool_args()),
               {H, S, Res} = run_commands(?MODULE, Cmds),
               ok = tulib_pool:stop(tulib_pool),
               wait_for_pid_death(Pid2),
               ok = stop(),
               wait_for_pid_death(Pid1),
               ?WHENFAIL(io:format("History: ~w\nState: ~w\nRes: ~w\n",
                                   [H,S,Res]),
                         aggregate(command_names(Cmds), Res =:= ok))
             end)).

wait_for_pid_death(Pid) ->
  lists:member(Pid, processes()) andalso wait_for_pid_death(Pid).

initial_state() -> #s{pid=tulib_pool, v=0}.

command(#s{pid=Pid} = _S) ->
  %% TODO:
  %% model timeouts somehow
  %% model caller_alive somehow
  ?LET({N, Timeout}, {pos_integer(), pos_integer()},
       oneof([ {call, ?MODULE, run,                    [Pid, N]}
             , {call, ?MODULE, run_timeout,            [Pid, N, Timeout]}
               %%         {call, ?MODULE, run_alive,              [Pid]},
               %%         {call, ?MODULE, run_not_alive,          [Pid]},
             , {call, ?MODULE, run_async,              [Pid, N]}
             , {call, ?MODULE, run_async_timeout,      [Pid, N, Timeout]}
               %%         {call, ?MODULE, run_async_alive,        [Pid]},
             , {call, ?MODULE, run_async_not_alive,    [Pid, N, Timeout]}
             , {call, ?MODULE, run_async_wait,         [Pid, N]}
             , {call, ?MODULE, run_async_wait_timeout, [Pid, N, Timeout]}
               %%         {call, ?MODULE, run_async_wait_alive,        [Pid]},
               %%         {call, ?MODULE, run_async_wait_not_alive,    [Pid]},
             , {call, ?MODULE, flush,                  [Pid]}
             ])).

%%%_ * Precondition ----------------------------------------------------
precondition(_S,                  {call, _, _,          _}) -> true.

%%%_ * Actions ---------------------------------------------------------
start_pool_args() ->
  [ {cbmod,          tulib_pool_test_worker}
  , {args,           []}
  , {size,           8}
  , {max_queue_size, infinity}
  ].

run(Pid, N) ->
  _ = tulib_pool:run(Pid, inctask(N)).

run_async(Pid, N) ->
  _ = tulib_pool:run_async(Pid, inctask(N)).

run_async_wait(Pid, N) ->
  _ = tulib_pool:run_async_wait(Pid, inctask(N)).

run_timeout(Pid, _N, Timeout) ->
  _ = tulib_pool:run(Pid, dummytask(5), [{queue_timeout, Timeout}]).

run_async_timeout(Pid, _N, Timeout) ->
  _ = tulib_pool:run_async(Pid, dummytask(5), [{queue_timeout, Timeout}]).

run_async_wait_timeout(Pid, _N, Timeout) ->
  _ = tulib_pool:run_async_wait(
        Pid, dummytask(5), [{queue_timeout, Timeout}]).

run_async_not_alive(Pid, _N, _Timeout) ->
  _ = tulib_pool:run_async(Pid, dummytask(5), [{caller_alive, false}]).

flush(Pid) ->
  tulib_pool:flush(Pid).

inctask(N) ->
  {execute, fun() -> inc(N) end}.

dummytask(Sleep) ->
  {execute, fun() -> timer:sleep(Sleep) end}.

%%%_ * State transitions -----------------------------------------------
next_state(S, _V, {call, _, Ct,  [_Pid, N]})
  when Ct =:= run
     ; Ct =:= run_async
     ; Ct =:= run_async_wait ->
  S#s{v=S#s.v+N};

next_state(S, _V, {call, _, Ct, [_Pid, _N, _Timeout]})
  when Ct =:= run_timeout
     ; Ct =:= run_async_timeout
     ; Ct =:= run_async_not_alive
     ; Ct =:= run_async_wait_timeout ->
  S;

next_state(S, _V, {call, _, flush, [_Pid]}) ->
  S.

%%%_ * Postconditions --------------------------------------------------
postcondition(S, {call, _, Ct, [_Pid, N]}, _R)
  when Ct =:= run
     ; Ct =:= run_async
     ; Ct =:= run_async_wait ->
  ok = expect(S#s.v+N),
  true;
postcondition(S, {call, _, Ct, [_Pid, _N, _Timeout]}, _R)
  when Ct =:= run_timeout
     ; Ct =:= run_async_timeout
     ; Ct =:= run_async_not_alive
     ; Ct =:= run_async_wait_timeout ->
  ok = expect(S#s.v),
  true;
postcondition(_S, {call, _, flush, [_Pid]}, _R) ->
  true.

%%%_ * gen_server for pool to work against -----------------------------
%% Idea is basically 'increase and update last value with n'.
%% We can then check if the postcondition is valid with expect/1.
-record(gs, {v=[0], wait=[]}).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [],[]).
stop()       -> gen_server:call(?MODULE, stop).
inc(N)       -> gen_server:call(?MODULE, {inc, N}).
expect(V)    -> gen_server:call(?MODULE, {expect, V}).

init([])            -> {ok, #gs{}}.
terminate(_Rsn, _S) -> ok.

handle_call({inc, N}, _From, #gs{v=[V0|_]=Vs0, wait=Wait0} = S) ->
  Vs = [V0+N|Vs0],
  case lists:keytake(V0+N, 1, Wait0) of
    {value, {_, From}, Wait} ->
      %% value was expected..
      gen_server:reply(From, ok),
      {reply, ok, S#gs{v=Vs, wait=Wait}};
    false ->
      {reply, ok, S#gs{v=Vs}}
  end;
handle_call({expect, V}, From, #gs{v=Vs, wait=Wait} = S) ->
  case lists:member(V, Vs) of
    true  -> {reply, ok, S};
    false -> {noreply, S#gs{wait=[{V,From}|Wait]}}
  end;
handle_call(stop, _From, S) ->
  {stop, normal, ok, S}.

handle_cast(Msg, S) -> ?warning("~p", [Msg]), {noreply, S}.
handle_info(Msg, S) -> ?warning("~p", [Msg]), {noreply, S}.

code_change(_, _, S) -> {ok, S}.
-endif.
-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
