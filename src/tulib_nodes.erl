%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Control Erlang nodes programatically.
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
-module(tulib_nodes).

%%%_* Exports ==========================================================
-export([ net_kernel_start/0
        , start/1
        , stop/1
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/assert.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
-spec net_kernel_start() -> maybe(_, _).
%% @doc
net_kernel_start() ->
  {ok, ""} = tulib_sh:eval("epmd -daemon"),
  case net_kernel:start([tulib_atoms:gensym(?MODULE), shortnames]) of
    {ok, _} = Ok                    -> Ok;
    {error, {already_started, Pid}} -> {ok, Pid};
    {error, _} = Err                -> Err
  end.


-spec start(atom()) -> node().
%% @doc Start a node with shortname Name.
start(Name) ->
  Node    = name_to_node(Name),
  {ok, _} = tulib_sh:eval("erl -sname " ++ ?a2l(Name) ++ " -detached"),
  tulib_loops:retry(?thunk(net_kernel:connect_node(Node) =:= true)),
  CodePath = [Dir || Dir <- code:get_path(), filelib:is_dir(Dir)], %Rebar
  true     = rpc:call(Node, code, set_path, [CodePath]),
  Node.

name_to_node(Name) ->
  {ok, Host} = inet:gethostname(),
  tulib_atoms:catenate([Name, '@', Host]).


-spec stop(node()) -> ok.
%% @doc Stop Node.
stop(Node) -> ok = rpc:call(Node, init, stop, []).

%%%_* Tests ============================================================
-ifdef(TEST).
-ifdef(NOJENKINS).

start_stop_test_() ->
  Name = tulib_atoms:gensym(test_node),
  Node = name_to_node(Name),
  net_kernel_start(),
  net_kernel_start(),
  {timeout, 10,
   {inorder,
    [ ?_assertMatch(Node, start(Name))
    , ?_assertMatch(pong, net_adm:ping(Node))
    , ?_assertMatch(ok,   stop(Node))
    , ?_assertMatch(ok,   timer:sleep(timer:seconds(2)))
    , ?_assertMatch(pang, net_adm:ping(Node))
    ]}}.

-endif.
-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
