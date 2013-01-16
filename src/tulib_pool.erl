%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Yet another worker pool.
%%%
%%% The Pool has three distinct mode of operations:
%%% 1. run synchronous (run)
%%%    Blocks until a worker is available (and done).
%%% 2. run asynchronous (run_async)
%%%    Returns as soon as task has been either enqueued or handed off to
%%%    a worker.
%%% 3. run asynchronous (run_async_wait)
%%%    Returns as soon as a task had been handed off to a worker.
%%%
%%% A couple of arguments are needed when starting a new pool:
%%% REQUIRED:
%%%    cbmod (worker callback module)
%%%    args  (arguments for callback)
%%%    size  (size of pool)
%%% OPTIONAL:
%%%    max_queue_size (max number of enqueued tasks)
%%%
%%% When starting a new task some options can be set (for that task):
%%% OPTIONAL:
%%%    queue_timeout (timeout for task waiting in queue)
%%%    caller_alive  (must caller be alive for task to be executed)
%%%
%%% In addition to the queue_timeout a timeout can be placed for the
%%% entire call (defaults to 5 seconds).
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
-module(tulib_pool).
-behaviour(gen_server).

%%%_* Exports ==========================================================
%% api
-export([ start/1
        , start/2
        , start_link/1
        , start_link/2
        , stop/1
        , run/2
        , run/3
        , run/4
        , run_async/2
        , run_async/3
        , run_async/4
        , run_async_wait/2
        , run_async_wait/3
        , run_async_wait/4
        , flush/1
        , flush/2
        ]).

%% gen_server
-export([ init/1
        , terminate/2
        , code_change/3
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        ]).

%% behaviour
-export([ behaviour_info/1
        ]).

-import(tulib_lists,
        [ assoc/2
        , assoc/3
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/assert.hrl").
-include_lib("tulib/include/logging.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Macros ===========================================================
%% defaults
-define(size,           8   ).
-define(max_queue_size, 5000).
-define(call_timeout,   5000).

-define(is_pool_bif(Cb), (Cb =:= tulib_pool_fun_executor)).

%%%_* Code =============================================================
%%%_ * Behaviour -------------------------------------------------------
behaviour_info(callbacks) ->
  [ {start_link, 1}
  , {stop,       1}
  , {run,        2}
  ];
behaviour_info(_) -> undefined.

%%%_ * Types -----------------------------------------------------------
-record(s, { %% user supplied
             cbmod          = undefined       :: atom()
           , args           = []              :: list()
           , size           = ?size           :: integer()
           , max_queue_size = ?max_queue_size :: integer()
             %% internal
           , free           = queue:new()     :: queue()   %workers
           , busy           = []              :: list()    %workers
           , workers        = []              :: list()    %all
           , n              = 1                            %counter
           , work           = gb_trees:empty()             %queue
           , expire         = gb_trees:empty()             %prio queue
           , flush          = []              :: list()    %requests
           }).

-record(task, { %% start of call in ms
                start_timestamp :: integer()
                %% options for task
              , options         :: list()
              , calltype        :: run | run_async | run_async_wait
              , task            :: any()
                %% request from
              , from
                %% request id
              , n
              }).

%%%_ * API -------------------------------------------------------------
start(Args)           -> gen_server:start(?MODULE, Args, []).
start(Reg, Args)      -> gen_server:start(Reg, ?MODULE, Args, []).
start_link(Args)      -> gen_server:start_link(?MODULE, Args, []).
start_link(Reg, Args) -> gen_server:start_link(Reg, ?MODULE, Args, []).
stop(Pid)             -> gen_server:call(Pid, stop).


run(Pid, Task) ->
  run(Pid, Task, []).
run(Pid, Task, Options) ->
  run(Pid, Task, Options, ?call_timeout).

-spec run(pid(), _, [_], integer()) -> maybe(_, _).
%% @doc run a task synchronously
run(Pid, Task, Options, Timeout) ->
  make_and_call(run, Pid, Task, Options, Timeout).


run_async(Pid, Task) ->
  run_async(Pid, Task, []).
run_async(Pid, Task, Options) ->
  run_async(Pid, Task, Options, ?call_timeout).

-spec run_async(pid(), Task, [_], integer()) -> maybe(Task, _).
%% @doc run a task asynchronously
run_async(Pid, Task, Options, Timeout) ->
  make_and_call(run_async, Pid, Task, Options, Timeout).


run_async_wait(Pid, Task) ->
  run_async_wait(Pid, Task, []).
run_async_wait(Pid, Task, Options) ->
  run_async_wait(Pid, Task, Options, ?call_timeout).

-spec run_async_wait(pid(), _, [_], integer()) -> maybe(pid(), _).
%% @doc run a task asynchronously, block until a worker is available
run_async_wait(Pid, Task, Options, Timeout) ->
  make_and_call(run_async_wait, Pid, Task, Options, Timeout).


flush(Pid) ->
  flush(Pid, ?call_timeout).

-spec flush(pid(), integer()) -> ok.
%% @doc wait for all tasks to finish, block new tasks.
flush(Pid, Timeout) ->
  gen_server:call(Pid, flush, Timeout).

%%%_ * gen_server callbacks --------------------------------------------
init(Args) ->
  erlang:process_flag(trap_exit, true),
  {ok, CbMod}     = assoc(cbmod,          Args),
  CbModArgs       = assoc(args,           Args, undefined),
  Size            = assoc(size,           Args, ?size),
  WorkMaxEnqueued = assoc(max_queue_size, Args, ?max_queue_size),

  Workers = start_workers(CbMod, CbModArgs, Size),
  {ok, #s{ cbmod          = CbMod
         , args           = CbModArgs
         , size           = Size
         , max_queue_size = WorkMaxEnqueued
         , free           = queue:from_list(Workers)
         , workers        = Workers
         }}.

terminate(_Rsn, #s{workers=Workers}) ->
  lists:foreach(fun(Pid) -> Pid ! {stop, self()} end, Workers),
  ok.

code_change(_OldVsn, S, _Extra) -> {ok, S, wait(S#s.expire)}.


handle_call(#task{}, _From, #s{flush=Flush, n=N} = S)
  when Flush =/= [] ->
  {reply, {error, flushing}, S#s{n = N+1}, wait(S#s.expire)};
handle_call(#task{} = Task0, From, #s{n = N} = S) ->
  Task = Task0#task{from = From, n = N},
  case queue:out(S#s.free) of
    {{value, Pid}, Free} ->
      %% free worker
      ?hence(gb_trees:size(S#s.work) =:= 0),
      ?debug("~p starting ~p", [Pid, Task]),
      Pid ! {run, Task, self()},
      reply_call(run_async,      Task, {ok, Task#task.task}),
      reply_call(run_async_wait, Task, {ok, Pid}),
      {noreply, S#s{ n    = N + 1
                   , free = Free
                   , busy = [{Pid,Task} | S#s.busy]
                   }, infinity};
    {empty, _Free} ->
      %% no free workers
      case gb_trees:size(S#s.work) >= S#s.max_queue_size of
        true  ->
          {reply, {error, queue_full}, S#s{n=N+1}, wait(S#s.expire)};
        false ->
          ?debug("enq ~p", [Task]),
          {Work, Expire} = enq_work(Task, S#s.work, S#s.expire),
          reply_call(run_async, Task, {ok, Task#task.task}),
          {noreply, S#s{ n      = N+1
                       , work   = Work
                       , expire = Expire
                       }, wait(Expire)}
      end
  end;
handle_call(flush, _From, #s{busy=[]} = S) ->
  ?hence(gb_trees:size(S#s.work) =:= 0),
  ?hence(gb_trees:size(S#s.expire) =:= 0),
  {reply, ok, S, infinity};
handle_call(flush, From, #s{flush = Flush} = S) ->
  {noreply, S#s{flush = [From|Flush]}, wait(S#s.expire)};
handle_call(stop, _From, S) ->
  {stop, normal, ok, S}.

handle_cast(_Msg, S) -> {noreply, S}.

handle_info({done, Res, Pid}, #s{} = S) ->
  ?hence(lists:member(Pid, S#s.workers)),
  {value, {Pid, Task}, Busy1} = lists:keytake(Pid, 1, S#s.busy),
  ?debug("~p done ~p", [Pid, Res]),
  reply_call(run, Task, ?lift(Res)),
  case deq_work(S#s.work, S#s.expire) of
    {{value, NextTask}, Work, Expire} ->
      ?debug("~p starting ~p", [Pid, NextTask]),
      Pid ! {run, NextTask, self()},
      reply_call(run_async_wait, NextTask, {ok, Pid}),
      {noreply, S#s{ work   = Work
                   , expire = Expire
                   , busy   = [{Pid,NextTask} | Busy1]
                   }, wait(Expire)};
    {empty, Work, Expire} ->
      reply_flush(S#s.flush),
      {noreply, S#s{ busy   = Busy1
                   , free   = queue:in(Pid, S#s.free)
                   , flush  = []
                   , work   = Work
                   , expire = Expire
                   }, infinity}
  end;
handle_info(timeout, #s{work = Work0, expire = Expire0} = S) ->
  {Work, Expire} = do_expire(tulib_util:timestamp() div 1000, Work0, Expire0),
  {noreply, S#s{work = Work, expire = Expire}, wait(Expire)};
handle_info({'EXIT', Pid, Rsn}, #s{workers = Workers} = S) ->
  ?hence(lists:member(Pid, Workers)),
  %% TODO: Handle worker crasches
  ?error("worker died ~p", [Rsn]),
  {stop, Rsn, S};
handle_info(Msg, S) ->
  ?warning("~p", [Msg]),
  {noreply, S, wait(S#s.expire)}.

%%%_ * Internals -------------------------------------------------------
make_and_call(Calltype, Pid, Task, Options, Timeout) ->
  case try_all(fun do_validate/1, Options) of
    ok ->
      gen_server:call(
        Pid, #task{ start_timestamp = tulib_util:timestamp() div 1000
                  , options         = Options
                  , task            = Task
                  , calltype        = Calltype
                  }, Timeout);
    {error, Rsn} ->
      {error, Rsn}
  end.

do_validate({caller_alive, Bool}) when erlang:is_boolean(Bool)    -> ok;
do_validate({queue_timeout, N})   when erlang:is_integer(N),N > 0 -> ok;
do_validate(Option) -> {error, {bad_option, Option}}.

try_all(F, [X|Xs]) ->
  case F(X) of
    ok           -> try_all(F, Xs);
    {error, Rsn} -> {error, Rsn}
  end;
try_all(_F, []) -> ok.

reply_call(Calltype, #task{calltype = Calltype, from = From}, Res) ->
  gen_server:reply(From, Res);
reply_call(_Calltype, _Task, _Res) -> ok.

reply_flush(Flush) ->
  lists:foreach(fun(From) -> gen_server:reply(From, ok) end, Flush).

%%%_ * Internals enqueue/dequeue  --------------------------------------
%% Two priority queues (gb_trees) are kept in sync to be able to handle
%% both queue ordering and expiration efficiently. In order to keep the
%% trees in sync the incoming requests are numbered starting from 1 (N).
%%
%% Queue has structure  {K:N, V:Task}
%% Expire has structure {K:{AbsoluteExpireTime, N}, V:N}
%%
%% Picking the next task to run or expire is then a O(log N)
%% operation.
enq_work(#task{options         = Options,
               start_timestamp = Start,
               n               = N} = Task, Work, Expire) ->
  case assoc(queue_timeout, Options, infinity) of
    infinity -> {gb_trees:insert(N, Task, Work), Expire};
    Timeout  -> {gb_trees:insert(N, Task, Work),
                 gb_trees:insert({Start + Timeout, N}, N, Expire)}
  end.

deq_work(Work0, Expire0) ->
  ?hence(gb_trees:size(Work0) >= gb_trees:size(Expire0)),
  case gb_trees:size(Work0) of
    0 -> {empty, Work0, Expire0};
    _ -> {N, #task{options = Options,
                   from    = {Pid, _},
                   n       = N} = Task, Work}
           = gb_trees:take_smallest(Work0),
         Expire = remove_from_expire(Task, Expire0),
         CallerAlive = assoc(caller_alive, Options, false),
         case {erlang:is_process_alive(Pid), CallerAlive} of
           {false, true} ->
             ?debug("caller not alive, dropping: ~p", [Task]),
             deq_work(Work, Expire);
           _ ->
             {{value, Task}, Work, Expire}
         end
  end.

remove_from_expire(Task, Expire) ->
  case assoc(queue_timeout, Task#task.options, infinity) of
    infinity -> Expire;
    Timeout  ->
      gb_trees:delete({Task#task.start_timestamp +
                       Timeout, Task#task.n}, Expire)
  end.

%%%_ * Internals timeouts/expire ---------------------------------------
%% @doc ms's until next task expire
wait(Expire) ->
  case gb_trees:size(Expire) of
    0 -> infinity;
    _ -> {{Timeout, N}, N} = gb_trees:smallest(Expire),
         ?hence(erlang:is_integer(Timeout)),
         ?hence(erlang:is_integer(N)),
         lists:max([Timeout - (tulib_util:timestamp() div 1000), 0])
  end.

%% @doc expire expired tasks.
do_expire(Now, Work0, Expire0) ->
  case gb_trees:size(Expire0) of
    0 -> {Work0, Expire0};
    _ -> case gb_trees:take_smallest(Expire0) of
           {{Timeout, N}, N, Expire} when Timeout =< Now ->
             Work = gb_trees:delete(N, Work0),
             Task = gb_trees:get(N, Work0),
             reply_call(run,            Task, {error, timeout}),
             reply_call(run_async_wait, Task, {error, timeout}),
             do_expire(Now, Work, Expire);
           {{_Timeout, _N}, _N, _Expire} ->
             {Work0, Expire0}
         end
  end.

%%%_ * Internals Worker related ----------------------------------------
start_workers(CbMod, Args, N) ->
  lists:map(fun(_) -> spawn_middleman(CbMod, Args) end, lists:seq(1, N)).

%% Reasoning behind using a middleman process is to simplify
%% implementation of a worker, whis way the worker process doesn't need
%% to know about the pool. The worker just gets a task, executes it
%% and returns.
spawn_middleman(CbMod, Args) ->
  Daddy = self(),
  erlang:spawn_link(fun() -> middleman(CbMod, Args, Daddy) end).

middleman(CbMod, _Args, Daddy) when ?is_pool_bif(CbMod) ->
  middleman_loop(CbMod, undefined, Daddy);
middleman(CbMod, Args, Daddy) ->
  {ok, Pid} = CbMod:start_link(Args),
  middleman_loop(CbMod, Pid, Daddy).

middleman_loop(CbMod, Pid, Daddy) ->
  receive
    {run, #task{task = Task}, Daddy} ->
      Daddy ! {done, run_task(CbMod, Pid, Task), self()},
      middleman_loop(CbMod, Pid, Daddy);
    {stop, Daddy} when ?is_pool_bif(CbMod) -> ok;
    {stop, Daddy}                          -> CbMod:stop(Pid);
    Msg ->
      ?warning("~p", [Msg]),
      middleman_loop(CbMod, Pid, Daddy)
  end.

run_task(CbMod, _Pid = undefined, Task)
  when ?is_pool_bif(CbMod) -> run_pool_bif(CbMod, Task);
run_task(CbMod, Pid, Task) -> CbMod:run(Pid, Task).

run_pool_bif(tulib_pool_fun_executor, Task) ->
  ?hence(erlang:is_function(Task, 0)),
  Task().

%%%_* Tests ============================================================
-ifdef(TEST).

start_stop_test() ->
  Args = [{cbmod, tulib_pool_test_worker}],
  {ok, Pid1} = tulib_pool:start(Args),
  {ok, Pid2} = tulib_pool:start({local, tulib_pool2}, Args),
  {ok, Pid3} = tulib_pool:start_link(Args),
  {ok, Pid4} = tulib_pool:start_link({local, tulib_pool4}, Args),
  Pid2 = whereis(tulib_pool2),
  Pid4 = whereis(tulib_pool4),
  ok = tulib_pool:stop(Pid1),
  ok = tulib_pool:stop(Pid2),
  ok = tulib_pool:stop(Pid3),
  ok = tulib_pool:stop(Pid4),
  ok.

return_values_test() ->
  Args = [{cbmod, tulib_pool_test_worker}, {args, []}, {size, 2}],
  {ok, Pid} = tulib_pool:start_link(Args),

  %% run
  {ok, foo} = tulib_pool:run(Pid, {execute, fun() -> foo end}),
  {ok, bar} = tulib_pool:run(Pid, {execute, fun() -> bar end}),

  %% run_async
  F1 = fun() -> foo end,
  F2 = fun() -> bar end,
  {ok, {execute, F1}} = tulib_pool:run_async(Pid, {execute, F1}),
  {ok, {execute, F2}} = tulib_pool:run_async(Pid, {execute, F2}),

  %% run_async_wait
  F3 = fun() -> baz end,
  F4 = fun() -> blah end,
  {ok, WorkerPid1} = tulib_pool:run_async_wait(Pid, {execute, F3}),
  {ok, WorkerPid2} = tulib_pool:run_async_wait(Pid, {execute, F4}),
  true = erlang:is_pid(WorkerPid1),
  true = erlang:is_pid(WorkerPid2),
  ok = tulib_pool:stop(Pid),
  ok.

options_test() ->
  F = fun(Options) -> tulib_pool:run(dummy, dummy, Options) end,
  {error, {bad_option, {queue_timeout, 0}}}  = F([{queue_timeout, 0}]),
  {error, {bad_option, {queue_timeout, -1}}} = F([{queue_timeout, -1}]),
  {error, {bad_option, {caller_alive, bar}}} = F([{caller_alive, bar}]),
  {error, {bad_option, {unknown_option, x}}} = F([{unknown_option, x}]),
  ok.

options_queue_timeout_test() ->
  Args      = [{cbmod, tulib_pool_test_worker}, {args, []}, {size, 1}],
  {ok, Pid} = tulib_pool:start_link(Args),
  Daddy     = self(),
  Task      = fun(Id) -> {execute, fun() -> Daddy ! Id end} end,

  %% make worker busy
  {ok, {execute, _}} =
    tulib_pool:run_async(Pid, {execute, fun() -> timer:sleep(1000) end}),

  %% call fails but task executed
  {'EXIT', {timeout, _}} =
    (catch tulib_pool:run(Pid, Task({1, success}), [], 0)),

  %% queue timeout
  {error, timeout} = tulib_pool:run(
                       Pid, Task({2, fail}), [{queue_timeout, 50}]),
  {ok, {execute, _}} =
    tulib_pool:run_async(Pid, Task({3, fail}), [{queue_timeout, 100}]),
  {ok, {execute, _}} =
    tulib_pool:run_async(Pid, Task({4, fail}), [{queue_timeout, 200}]),

  %% no queue timeout
  {ok, {execute, _}} =
    tulib_pool:run_async(Pid, Task({5, success}), [{queue_timeout, 5000}]),
  ok = tulib_pool:flush(Pid),

  {messages, Messages} = erlang:process_info(self(), messages),
  true = lists:all(fun({_N, fail}) -> false;
                      (_         ) -> true
                   end, Messages),
  true = lists:member({1, success}, Messages),
  true = lists:member({5, success}, Messages),
  tulib_pool:stop(Pid),
  ok.

options_caller_alive_test() ->
  Args = [{cbmod, tulib_pool_fun_executor}, {size, 1}],
  {ok, Pid} = tulib_pool:start_link(Args),

  %% make worker busy
  %% TODO: refactor to remove timer
  tulib_pool:run_async(Pid, fun() -> timer:sleep(1000) end),
  Daddy = self(),
  F = fun() ->
          tulib_pool:run_async(Pid, fun() -> Daddy ! safe end,
                               [{caller_alive, true}]),
          tulib_pool:run_async(Pid, fun() -> Daddy ! word end,
                               [{caller_alive, false}])
      end,
  proc_lib:spawn_link(F),
  receive safe -> erlang:error(caller_alive);
          word -> ok
  end,
  tulib_pool:stop(Pid),
  ok.

flush_test() ->
  Args       = [{cbmod, tulib_pool_test_worker}, {args, []}, {size, 2}],
  {ok, Pid}  = tulib_pool:start_link(Args),
  Task       = {execute, fun() -> timer:sleep(1000) end},

  ok         = tulib_pool:flush(Pid),
  {ok, Task} = tulib_pool:run_async(Pid, Task),
  Pid2 = erlang:spawn_link(fun() -> tulib_pool:flush(Pid, 5000) end),
  until_process_info(Pid2, {status, waiting}),
  {error, flushing} = tulib_pool:run_async(Pid, Task),
  {'EXIT', {timeout, _}} = (catch tulib_pool:flush(Pid, 500)),
  ok   = tulib_pool:flush(Pid, 5000),
  ok   = tulib_pool:stop(Pid),
  ok.

queue_full_test() ->
  Args      = [{cbmod, tulib_pool_fun_executor},
               {size,  1},
               {max_queue_size, 2}],
  {ok, Pid} = tulib_pool:start_link(Args),
  F         = fun() -> timer:sleep(1000) end,

  {ok, F} = tulib_pool:run_async(Pid, F),   %% running
  {ok, F} = tulib_pool:run_async(Pid, F),   %% in queue
  {ok, F} = tulib_pool:run_async(Pid, F),   %% in queue
  {error, queue_full} = tulib_pool:run(Pid, F),
  {error, queue_full} = tulib_pool:run_async(Pid, F),
  {error, queue_full} = tulib_pool:run_async_wait(Pid, F),
  tulib_pool:stop(Pid),
  ok.

stray_messages_test() ->
  Args      = [{cbmod, tulib_pool_test_worker}, {args, []}],
  {ok, Pid} = tulib_pool:start_link(Args),
  Task      = {execute, fun() -> success end},

  Pid ! oops,
  {links, Middlemen} = erlang:process_info(Pid, links),
  lists:foreach(fun(MM) -> MM ! oops end, Middlemen),
  {ok, success} = tulib_pool:run(Pid, Task),
  tulib_pool:stop(Pid),
  ok.

worker_crash_test() ->
  Args      = [{cbmod, tulib_pool_test_worker}, {args, []}],
  {ok, Pid} = tulib_pool:start(Args),
  Task      = {execute, fun() -> ok end},

  {ok, Worker} = tulib_pool:run_async_wait(Pid, Task),
  exit(Worker, die),
  until_dead(Pid),
  ok.

code_change_test() ->
  Args = [{cbmod, tulib_pool_fun_executor}],
  {ok, Pid} = tulib_pool:start_link({local, tulib_pool}, Args),
  sys:suspend(Pid, infinity),
  sys:change_code(tulib_pool, tulib_pool, old_vsn, extra),
  sys:resume(Pid, infinity),
  tulib_pool:stop(Pid),
  ok.

stupid_full_cover_test() ->
  _         = tulib_pool:behaviour_info(callbacks),
  undefined = tulib_pool:behaviour_info(blah),
  ok.

until_process_info(Pid, {K, V}) ->
  case erlang:process_info(Pid, K) of
    {K, V} -> ok;
    {K, _} -> until_process_info(Pid, {K, V})
  end.

until_dead(Pid) ->
  case erlang:is_process_alive(Pid) of
    true  -> until_dead(Pid);
    false -> ok
  end.

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:

