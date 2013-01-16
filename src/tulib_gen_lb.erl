%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc ALPHA: Load-balance requests across a cluster of gen_servers.
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
-module(tulib_gen_lb).
-behaviour(gen_server).

%%%_* Exports ==========================================================
%% API
-export([ start/1
        , start/2
        , start_link/1
        , start_link/2
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

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/assert.hrl").
-include_lib("tulib/include/logging.hrl").

%%%_* Code =============================================================
%%%_ * API -------------------------------------------------------------
start(A)            -> gen_server:start(?MODULE, A, []).
start(Name, A)      -> gen_server:start({local, Name}, ?MODULE, A, []).
start_link(A)       -> gen_server:start_link(?MODULE, A, []).
start_link(Name, A) -> gen_server:start_link({local, Name}, ?MODULE, A, []).

stop(LB)            -> gen_server:cast(LB, stop).

%%%_ * gen_server callbacks --------------------------------------------
-record(s,
       { gs_cb   :: atom()  %gen_server callback
       , gs_args :: _       %gen_server args
       , cluster :: [pid()] %cluster of gen_servers which handle requests
       }).

init(Args) ->
  process_flag(trap_exit, true),
  {ok, GsCb}   = tulib_lists:assoc(gs_cb,        Args),
  {ok, GsArgs} = tulib_lists:assoc(gs_args,      Args),
  ClusterSize  = tulib_lists:assoc(cluster_size, Args, 10),
  #s{ gs_cb      = GsCb
    , gs_args    = GsArgs
    , cluster    = [GsCb:start_link(GsArgs) ||
                     _ <- tulib_lists:seq(ClusterSize)]
    }.

terminate(_, #s{cluster=Pids}) ->
  [Pid ! {'$gen_cast', stop} || Pid <- Pids],
  ok.

code_change(_, S, _) -> {ok, S}.

handle_call(Msg, From, #s{cluster=[Pid|Pids]} = S) ->
  Pid ! {'$gen_call', From, Msg},
  {noreply, S#s{cluster=Pids ++ [Pid]}}. %round robin

handle_cast(stop, S) -> {stop, normal, S}.

handle_info({'EXIT', Pid, Rsn},
            #s{gs_cb=GsCb, gs_args=GsArgs, cluster=Pids} = S) ->
  ?error("EXIT: ~p: ~p", [Pid, Rsn]),
  ?hence(lists:member(Pid, Pids)),
  {noreply, S#s{cluster=[GsCb:start_link(GsArgs)] ++ Pids -- [Pid]}};
handle_info(Msg, S) ->
  ?warning("~p", [Msg]),
  {noreply, S}.

%%%_* Tests ============================================================
-ifdef(TEST).

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
