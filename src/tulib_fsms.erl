%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Mealy machines.
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
-module(tulib_fsms).

%%%_* Exports ==========================================================
-export([ consume/2
        , current_state/1
        , new/3
        ]).

-export_type([ fsm/0
             , state/0
             , transition_fun/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/assert.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * Types -----------------------------------------------------------
-record(fsm,
        { label        :: atom()
        , s            :: state()
        , t            :: transition_fun()
        }).

-type state()          :: {state_sym(), state_data()}.
-type state_sym()      :: _.
-type state_data()     :: _.

-type input()          :: {input_sym(), input_data()}.
-type input_sym()      :: _.
-type input_data()     :: _.

-type transition_fun() :: fun((state(), input()) -> state()).

-opaque fsm()          :: #fsm{}.

%%%_ * API -------------------------------------------------------------
-spec new(atom(), state(), transition_fun()) -> fsm().
new(Label, InitialState, TransitionFun)
  when is_atom(Label)
     , is_function(TransitionFun, 2) ->
  ?hence(is_tagged_data(InitialState)),
  #fsm{label=Label, s=InitialState, t=TransitionFun}.

-spec current_state(fsm()) -> state().
current_state(#fsm{s=S})   -> S.

-spec consume(fsm(), input()) -> fsm().
consume(#fsm{s=S0, t=T} = Fsm, Input) ->
  ?hence(is_tagged_data(Input)),
  case ?lift(T(S0, Input)) of
    {ok, S} ->
      ?hence(is_tagged_data(S)),
      Fsm#fsm{s=S};
    {error, Rsn} ->
      throw({error, {bad_input, Fsm#fsm.label, S0, Input, Rsn}})
  end.


is_tagged_data({_, _}) -> true;
is_tagged_data(_)      -> false.

%%%_* Tests ============================================================
-ifdef(TEST).

basic_test() ->
  Xor = new('xor',
            {s_i, ''},
            fun({s_i, _}, {0, _}) -> {s_0, 0};
               ({s_i, _}, {1, _}) -> {s_1, 0};
               ({s_0, _}, {0, _}) -> {s_0, 0};
               ({s_0, _}, {1, _}) -> {s_1, 1};
               ({s_1, _}, {0, _}) -> {s_0, 1};
               ({s_1, _}, {1, _}) -> {s_1, 0}
            end),

  {_, 0} = current_state(consume(consume(Xor, {0, ''}), {0, ''})),
  {_, 1} = current_state(consume(consume(Xor, {0, ''}), {1, ''})),
  {_, 1} = current_state(consume(consume(Xor, {1, ''}), {0, ''})),
  {_, 0} = current_state(consume(consume(Xor, {1, ''}), {1, ''})),

  {error, {bad_input, 'xor', {s_i, ''}, {foo,bar}, _}} =
    ?lift(consume(Xor, {foo, bar})),
  {error, {assert, _, _, _}} =
    ?lift(consume(Xor, foo)),

  ok.

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
