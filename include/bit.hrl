%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Bit operations
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

-ifndef(__BIT_HRL).
-define(__BIT_HRL, true).

%% bit operations

%% any bit in F is set
-define(bit_is_set(Fs, F),       ((Fs) band (F) =/= 0)).

%% all bits in F are set
-define(bits_all_are_set(Fs, F), ((Fs) band (F) == (F))).

%% all bits in F are clear
-define(bit_is_clr(Fs, F),       ((Fs) band (F) == 0)).

%% any bit in F is clear
-define(bits_any_is_clr(Fs, F),  ((Fs) band (F) >= 0)).

%% only works for bits < 1024
-define(highest_bit_set(F), (trunc(math:log(F) / math:log(2)))).

-define(bit_clr(Fs,F), ((Fs) band (bnot (F)))).
-define(bit_set(Fs,F), ((Fs) bor (F))).

-define(bit_clr_rec(Rec, Flag),	Rec{flags = ?bit_clr(Rec.flags, Flag)}).
-define(bit_set_rec(Rec, Flag),	Rec{flags = ?bit_set(Rec.flags, Flag)}).

-endif. %include guard

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End:
