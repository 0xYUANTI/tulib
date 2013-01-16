%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Parallel computation.
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
-module(tulib_par).

%%%_* Exports ==========================================================
-export([ eval/2
        , eval/3
        , eval/4
        ]).

-export_type([ opt/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/assert.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
-type opt() :: {errors,     boolean()}
             | {workers,    non_neg_integer()}
             | {chunk_size, non_neg_integer()}.

eval(F, Xs) ->
  eval(F, Xs, []).
eval(F, Xs, Opts) ->
  eval(F, Xs, Opts, infinity).

-spec eval(fun((A) -> B), [A], [opt()], timeout()) ->
              maybe([maybe(B, _) | B], _).
%% @doc Evaluate F for each element of Xs in parallel.
eval(_, [], Opts, _) ->
  ?hence(ensure_opts(Opts)),
  {ok, []};
eval(F, Xs, Opts, Timeout) ->
  ?hence(ensure_opts(Opts)),
  Errors         = tulib_lists:assoc(errors,     Opts, true),
  Workers        = tulib_lists:assoc(workers,    Opts, 0),
  ChunkSize      = tulib_lists:assoc(chunk_size, Opts, 0),
  {Pid, Monitor} = spawn_middleman(F, Xs, Errors, Workers, ChunkSize, self()),
  receive
    {Pid, Ret} ->
      erlang:demonitor(Monitor, [flush]),
      Ret;
    {'DOWN', Monitor, process, Pid, Rsn} ->
      ?hence(Rsn =/= normal),
      {error, {middleman, Rsn}}
  after
    Timeout ->
      tulib_processes:kill(Pid),
      erlang:demonitor(Monitor, [flush]),
      {error, timeout}
  end.

ensure_opts(Opts)       -> lists:all(fun is_opt/1, Opts).
is_opt({errors, Flag})  -> is_boolean(Flag);
is_opt({workers, N})    -> is_integer(N) andalso N > 0;
is_opt({chunk_size, N}) -> is_integer(N) andalso N > 0.

spawn_middleman(F, Xs, Errors, Workers, ChunkSize, Parent) ->
  spawn_monitor(?thunk(
    process_flag(trap_exit, true),
    Monitor = erlang:monitor(process, Parent),
    Pids    = spawn_workers(F, Xs, Workers, ChunkSize),
    middleman(Errors, Parent, Monitor, Pids, []))).

middleman(_Errors, Parent, _Monitor, [], Acc) ->
  tulib_processes:send(Parent, {ok, Acc});
middleman(Errors, Parent, Monitor, Pids, Acc) ->
  receive
    {'EXIT', Pid, normal} ->
      %% No assert since that would create a race between this clause
      %% and the {Pid, Rets} clauses below.
      middleman(Errors,
                Parent,
                Monitor,
                Pids -- [Pid],
                Acc);
    {'EXIT', Pid, Rsn} when Errors ->
      ?hence(lists:member(Pid, Pids)),
      middleman(Errors,
                Parent,
                Monitor,
                Pids -- [Pid],
                [{error, {exit, Rsn}}|Acc]);
    {'EXIT', Pid, Rsn} when not Errors ->
      ?hence(lists:member(Pid, Pids)),
      tulib_processes:send(Parent, {error, {worker, {exit, Rsn}}}),
      exit(worker);
    {'DOWN', Monitor, process, Parent, Rsn} ->
      exit({parent, Rsn});
    {Pid, Rets} when Errors ->
      ?hence(lists:member(Pid, Pids)),
      middleman(Errors, Parent, Monitor, Pids -- [Pid], Rets ++ Acc);
    {Pid, Rets} when not Errors ->
      ?hence(lists:member(Pid, Pids)),
      {Ress, Rsns} = tulib_maybe:partition(Rets),
      case Rsns of
        [] ->
          middleman(Errors, Parent, Monitor, Pids -- [Pid], Ress ++ Acc);
        [_|_] ->
          tulib_processes:send(Parent, {error, {worker, Rsns}}),
          exit(worker)
      end
  end.

spawn_workers(F, Xs, Workers, ChunkSize) ->
  Chunks = chunk(Xs, Workers, ChunkSize),
  Self   = self(),
  [proc_lib:spawn_link(?thunk(worker(F, C, Self))) || C <- Chunks].

chunk(Xs, Workers, ChunkSize) ->
  Len = length(Xs),
  tulib_lists:partition(divide(Len, chunks(Len, Workers, ChunkSize)), Xs).

%%     Len Workers ChunkSize        Chunks
chunks(L,  0,      0)            -> L;
chunks(L,  0,      C) when L > C -> divide(L, C);
chunks(_,  0,      _)            -> 1;
chunks(L,  W,      0) when L > W -> W;
chunks(L,  _,      0)            -> L;
chunks(L,  W,      C)            -> max(chunks(L, W, 0), chunks(L, 0, C)).

divide(N, M) when N rem M =:= 0 -> N div M;
divide(N, M) when N rem M =/= 0 -> N div M + 1.

worker(F, Chunk, Parent) ->
  tulib_processes:send(Parent, [?lift(F(X)) || X <- Chunk]).

%%%_* Tests ============================================================
-ifdef(TEST).

basic_test() ->
  {ok, []} = eval(fun(_) -> 42 end, []),
  {ok, Ys} = eval(fun(X) -> X+1 end,
                  [1, 2, 3],
                  [{workers, 2}, {chunk_size, 1}]),
  ?assert(length(Ys) =:= 3),
  ?assert(lists:member({ok, 2}, Ys)),
  ?assert(lists:member({ok, 3}, Ys)),
  ?assert(lists:member({ok, 4}, Ys)).

errors_test() ->
  {ok, Ys} = eval(fun(X) -> X+1 end, [1, 2, 3], [{errors, false}]),
  ?assert(length(Ys) =:= 3),
  ?assert(lists:member(2, Ys)),
  ?assert(lists:member(3, Ys)),
  ?assert(lists:member(4, Ys)),
  {error, {worker, _}} = eval(fun(X) -> 1/X end, [0, 1, 2], [{errors, false}]),
  {ok, [{error, foo}]} = eval(fun(F) -> F() end,
                              [?thunk({error, foo})],
                              [{errors, true}]),
  ok.

chunk_test() ->
  Xs                        = [1,2,3,4,5],
  [[1], [2], [3], [4], [5]] = chunk(Xs, 0, 0),
  [[1,2,3], [4,5]]          = chunk(Xs, 0, 4),
  [[1, 2, 3, 4, 5]]         = chunk(Xs, 0, 6),
  [[1,2,3], [4,5]]          = chunk(Xs, 2, 0),
  [[1], [2], [3], [4], [5]] = chunk(Xs, 6, 0),
  [[1,2], [3,4], [5]]       = chunk(Xs, 2, 2),
  ok.

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
