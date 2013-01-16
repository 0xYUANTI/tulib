%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc test worker
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
-module(tulib_pool_test_worker).
-behaviour(tulib_pool).

%%%_* Exports ==========================================================
-export([ start_link/1
        , stop/1
        , run/2
        ]).

-export([ init/1
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , code_change/3
        , terminate/2
        ]).

%%%_* Code =============================================================
%%%_ * Types -----------------------------------------------------------
-record(s, {}).

%%%_ * API -------------------------------------------------------------
start_link(Args) -> gen_server:start_link(?MODULE, Args, []).
stop(Pid)        -> gen_server:cast(Pid, stop).
run(Pid, Task)   -> gen_server:call(Pid, {run, Task}, infinity).

%%%_ * Callbacks -------------------------------------------------------
init(_Args) ->
  {ok, #s{}}.

handle_call({run, {execute, Fun}}, _From, S) ->
  {reply, Fun(), S}.

handle_cast(stop, S) ->
  {stop, normal, S}.

handle_info(_Info, S) ->
  {noreply, S}.

terminate(_Rsn, _S) ->
  ok.

code_change(_OldVsn, S, _Extra) ->
  {ok, S}.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
