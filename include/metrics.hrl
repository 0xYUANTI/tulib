%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Metrics-related convenience macros.
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

-ifndef(__METRICS_HRL).
-define(__METRICS_HRL, true).

-ifdef(TULIB_USE_FOLSOM).

-define(regp, (lists:member(folsom_sup, registered()))).

-define(do_increment(Key),
        (?regp andalso folsom_metrics:notify(Key, {inc, 1}, counter))).
-define(do_increment(Key, N),
        (?regp andalso folsom_metrics:notify(Key, {inc, N}, counter))).
-define(do_decrement(Key),
        (?regp andalso folsom_metrics:notify(Key, {dec, 1}, counter))).
-define(do_decrement(Key, N),
        (?regp andalso folsom_metrics:notify(Key, {dec, N}, counter))).
-define(do_time(Key, Expr),
        (case ?regp of
           true  -> folsom_metrics:histogram_timed_update(Key, ?thunk(Expr));
           false -> Expr
         end)).
-define(do_meter(Key, N),
        (?regp andalso folsom_metrics:notify(Key, N, meter))).
-define(do_meter_read(Key, N),
        (?regp andalso folsom_metrics:notify(Key, N, meter_read))).
-define(do_spiral(Key, N),
        (?regp andalso folsom_metrics:notify(Key, N, spiral))).

-else.

-define(do_increment(Key),    ok).
-define(do_increment(Key, N), ok).
-define(do_decrement(Key),    ok).
-define(do_decrement(Key, N), ok).
-define(do_time(Key, Expr),   Expr).
-define(do_meter(Key, N), ok).
-define(do_meter_read(Key, N), ok).
-define(do_spiral(Key, N), ok).

-endif.

-ifndef(TULIB_METRICS_PREFIX).
-define(TULIB_METRICS_PREFIX, tulib).
-endif.

-define(name(Name),
        tulib_atoms:catenate(
          tulib_lists:intersperse(
            '_',
            [?TULIB_METRICS_PREFIX|Name]))).

-define(increment(Key),     ?do_increment(?name(Key))).
-define(increment(Key, N),  ?do_increment(?name(Key), N)).
-define(decrement(Key),     ?do_decrement(?name(Key))).
-define(decrement(Key, N),  ?do_decrement(?name(Key), N)).
-define(time(Key, Expr),    ?do_time(?name(Key), Expr)).
-define(meter(Key, N),      ?do_meter(?name(Key), N)).
-define(meter_read(Key, N), ?do_meter_read(?name(Key), N)).
-define(spiral(Key, N),     ?do_spiral(?name(Key), N)).

-endif. %include guard

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End:
