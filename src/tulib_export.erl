%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Exporter.
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
-module(tulib_export).

%%%_* Exports ==========================================================
-export([ all/1
        , call/3
        ]).

-export([ parse_transform/2
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/guards.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
-spec all(atom()) -> maybe(_, _).
%% @doc Recompile Mod with export_all, without access to the source.
all(Mod) ->
  case code:which(Mod) of
    File when ?is_string(File) ->
      tulib_maybe:lift(?thunk(
        %% Get abstract code
        {ok, {Mod, [AbstractCode]}} = beam_lib:chunks(File, [abstract_code]),
        {abstract_code, {_, Forms}} = AbstractCode,
        %% Recompile
        {ok, Mod, Bin}              = compile:forms(Forms, [export_all]),
        %% Reload
        true                        = code:soft_purge(Mod),
        {module, Mod}               = code:load_binary(Mod, "", Bin),
        Mod));
    Other -> {error, Other}
  end.


-spec call(atom(), atom(), [_]) -> maybe(_, _).
%% @doc Call M:F(A) when M doesn't export F.
call(M, F, A) when not is_list(A) ->
  call(M, F, [A]);
call(M, F, A) ->
  tulib_maybe:lift(?thunk(
    %% Recompile/load M with F exported
    {ok, File}   = tulib_lists:assoc(source, M:module_info(compile)),
    {ok, M, Bin} = compile:file(File, [ {parse_transform, ?MODULE}
                                      , {export_fun, {F, length(A)}}
                                      , binary
                                      ]),
    true         = code:soft_purge(M),
    {module, M}  = code:load_binary(M, "", Bin),
    %% Call F
    Res          = apply(M, 'APPLY', A),
    %% Reload original version of M
    true         = code:soft_purge(M),
    {module, M}  = code:load_file(M),
    %% Return result
    Res)).

parse_transform(AbstractCode0, Opts) ->
  case tulib_lists:assoc(export_fun, Opts) of
    {ok, {F, Arity}} ->
      N             = last_line(AbstractCode0),
      AbstractCode1 = add_form(AbstractCode0, mk_apply(F, Arity, N), N+4),
      add_export(AbstractCode1, {'APPLY', Arity});
    {error, notfound} ->
      AbstractCode0
  end.

last_line(AbstractCode) ->
  {eof, Line} = lists:last(AbstractCode),
  Line.

mk_apply(F, Arity, N) ->
  {function, N+1, 'APPLY', Arity,
   [{clause, N+2, mk_vars(Arity, N+2), [],
     [{call, N+3, {'fun', N+3, {function, F, Arity}}, mk_vars(Arity, N+3)}]}]}.

mk_vars(0,   _)    -> [];
mk_vars(Idx, Line) -> [{var, Line, mk_var(Idx)}|mk_vars(Idx-1, Line)].

mk_var(Idx)        -> tulib_atoms:catenate(['V', Idx]).

add_form([{eof, _Line}], NewForm, Line) ->
  [NewForm, {eof, Line}];
add_form([Form|Forms],  NewForm, Line) ->
  [Form|add_form(Forms, NewForm, Line)].

add_export([{attribute, Line, export, Exports}|Forms], Export) ->
  [{attribute, Line, export, [Export|Exports]}|Forms];
add_export([Form|Forms], Export) ->
  [Form|add_export(Forms, Export)];
add_export([], _Export) ->
  [].

%%%_* Tests ============================================================
-ifdef(TEST).
-ifdef(NOCOVER).

-define(MOD, test_module).
-define(safe(Expr), (try Expr catch _:_ -> exn end)).

all_test() ->
  exn            = ?safe(?MOD:unexported()),
  {ok, _}        = tulib_export:all(?MOD),
  ok             = ?MOD:unexported(),
  true           = code:soft_purge(?MOD),
  {module, ?MOD} = code:load_file(?MOD),
  exn            = ?safe(?MOD:unexported()),
  ok.

call_test() ->
  exn            = ?safe(?MOD:unexported()),
  {ok, ok}       = tulib_export:call(?MOD, unexported, []),
  exn            = ?safe(?MOD:unexported()),
  ok.

-endif.
-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
