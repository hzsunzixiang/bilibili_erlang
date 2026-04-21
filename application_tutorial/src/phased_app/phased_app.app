%% -*- erlang -*-
%% Application resource file for phased_app.
%% Demonstrates start_phases configuration.
{application, phased_app,
 [{description, "Phased Application with start_phases example"},
  {vsn, "1.0.0"},
  {modules, [phased_app, phased_app_sup, simple_worker]},
  {registered, [phased_app_sup]},
  {applications, [kernel, stdlib]},
  {mod, {phased_app, []}},
  {start_phases, [{init, []}, {go, []}]}
 ]}.
