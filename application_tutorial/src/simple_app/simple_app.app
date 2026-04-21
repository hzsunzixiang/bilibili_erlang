%% -*- erlang -*-
%% Application resource file for simple_app.
%% Place this file in the same directory as the .beam files,
%% or in an ebin/ directory.
{application, simple_app,
 [{description, "Simple Application behaviour example"},
  {vsn, "1.0.0"},
  {modules, [simple_app, simple_app_sup, simple_worker]},
  {registered, [simple_app_sup, simple_worker]},
  {applications, [kernel, stdlib]},
  {mod, {simple_app, []}}
 ]}.
