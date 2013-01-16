%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc More convenient Meck interface.
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
-module(tulib_meck).

%%%_* Exports ==========================================================
-export([ defaultify/1
        , faultify/1
        , mock/2
        , unmock/1
        , with_faulty/2
        , with_mocked/3
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/logging.hrl").
-include_lib("tulib/include/prelude.hrl").

%%%_* Code =============================================================
%%%_ * Mocking ---------------------------------------------------------
mock({M, F, _A}, Fun) ->
  meck:new(M, [passthrough]),
  meck:expect(M, F, Fun).

unmock({M, _F, _A}) ->
  ?debug("~p valid: ~p", [M, meck:validate(M)]),
  meck:unload(M).

with_mocked(MFA, Fun, Thunk) ->
  try mock(MFA, Fun), Thunk()
  after unmock(MFA)
  end.

%%%_ * Faultification --------------------------------------------------
faultify({M, F, A}) ->
  meck:new(M, [passthrough]),
  meck:expect(M, F, faulty(A)).

defaultify(MFA) -> unmock(MFA).

with_faulty(MFA, Thunk) ->
  try faultify(MFA), Thunk()
  after defaultify(MFA)
  end.

%% If you have a procedure with ten parameters, you probably missed some.
%%   --Alan Perlis
faulty([]) ->
  fun() -> exn() end;
faulty([A]) ->
  fun(A_) when A =:= A_ orelse A =:= '_' -> exn();
     (A_)                                -> meck:passthrough([A_])
  end;
faulty([A, B]) ->
  fun(A_, B_)
     when A =:= A_ orelse A =:= '_'
        , B =:= B_ orelse B =:= '_' ->
      exn();
     (A_, B_) -> meck:passthrough([A_, B_])
  end;
faulty([A, B, C]) ->
  fun(A_, B_, C_)
     when A =:= A_ orelse A =:= '_'
        , B =:= B_ orelse B =:= '_'
        , C =:= C_ orelse C =:= '_' ->
      exn();
     (A_, B_, C_) -> meck:passthrough([A_, B_, C_])
  end;
faulty([A, B, C, D]) ->
  fun(A_, B_, C_, D_)
     when A =:= A_ orelse A =:= '_'
        , B =:= B_ orelse B =:= '_'
        , C =:= C_ orelse C =:= '_'
        , D =:= D_ orelse D =:= '_' ->
      exn();
     (A_, B_, C_, D_) -> meck:passthrough([A_, B_, C_, D_])
  end;
faulty([A, B, C, D, E]) ->
  fun(A_, B_, C_, D_, E_)
     when A =:= A_ orelse A =:= '_'
        , B =:= B_ orelse B =:= '_'
        , C =:= C_ orelse C =:= '_'
        , D =:= D_ orelse D =:= '_'
        , E =:= E_ orelse E =:= '_' ->
      exn();
     (A_, B_, C_, D_, E_) -> meck:passthrough([A_, B_, C_, D_, E_])
  end;
faulty([A, B, C, D, E, F]) ->
  fun(A_, B_, C_, D_, E_, F_)
     when A =:= A_ orelse A =:= '_'
        , B =:= B_ orelse B =:= '_'
        , C =:= C_ orelse C =:= '_'
        , D =:= D_ orelse D =:= '_'
        , E =:= E_ orelse E =:= '_'
        , F =:= F_ orelse F =:= '_' ->
      exn();
     (A_, B_, C_, D_, E_, F_) -> meck:passthrough([A_, B_, C_, D_, E_, F_])
  end;
faulty([A, B, C, D, E, F, G]) ->
  fun(A_, B_, C_, D_, E_, F_, G_)
     when A =:= A_ orelse A =:= '_'
        , B =:= B_ orelse B =:= '_'
        , C =:= C_ orelse C =:= '_'
        , D =:= D_ orelse D =:= '_'
        , E =:= E_ orelse E =:= '_'
        , F =:= F_ orelse F =:= '_'
        , G =:= G_ orelse G =:= '_' ->
      exn();
     (A_, B_, C_, D_, E_, F_, G_) ->
      meck:passthrough([A_, B_, C_, D_, E_, F_, G_])
  end;
faulty([A, B, C, D, E, F, G, H]) ->
  fun(A_, B_, C_, D_, E_, F_, G_, H_)
     when A =:= A_ orelse A =:= '_'
        , B =:= B_ orelse B =:= '_'
        , C =:= C_ orelse C =:= '_'
        , D =:= D_ orelse D =:= '_'
        , E =:= E_ orelse E =:= '_'
        , F =:= F_ orelse F =:= '_'
        , G =:= G_ orelse G =:= '_'
        , H =:= H_ orelse H =:= '_' ->
      exn();
     (A_, B_, C_, D_, E_, F_, G_, H_) ->
      meck:passthrough([A_, B_, C_, D_, E_, F_, G_, H_])
  end;
faulty([A, B, C, D, E, F, G, H, I]) ->
  fun(A_, B_, C_, D_, E_, F_, G_, H_, I_)
     when A =:= A_ orelse A =:= '_'
        , B =:= B_ orelse B =:= '_'
        , C =:= C_ orelse C =:= '_'
        , D =:= D_ orelse D =:= '_'
        , E =:= E_ orelse E =:= '_'
        , F =:= F_ orelse F =:= '_'
        , G =:= G_ orelse G =:= '_'
        , H =:= H_ orelse H =:= '_'
        , I =:= I_ orelse I =:= '_' ->
      exn();
     (A_, B_, C_, D_, E_, F_, G_, H_, I_) ->
      meck:passthrough([A_, B_, C_, D_, E_, F_, G_, H_, I_])
  end.

exn() -> meck:exception(error, ?MODULE).

%%%_* Tests ============================================================
-ifdef(TEST).
-ifdef(NOCOVER).

basic_test() ->
  Mod = meck_test_mod,
  {'EXIT', {tulib_meck, _}} =
    (catch with_faulty({Mod, f, [x]}, ?thunk(Mod:f(x)))),
  bar = with_faulty({Mod, f, [x]}, ?thunk(Mod:f(y))),
  ok.

-endif.
-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
