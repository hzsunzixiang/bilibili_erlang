full_otp_app - OTP Application Demo
=====================================

This project demonstrates a complete OTP application that combines
multiple OTP behaviours under a single supervisor tree.

Architecture
------------

    full_otp_app (application)
        |
        +-- full_otp_app_sup (supervisor, one_for_one)
                |
                +-- kv_server       (gen_server)  - Key-Value Store
                |
                +-- event_bus       (gen_event)   - Event Manager
                |       |
                |       +-- event_bus_handler     - Default log handler
                |
                +-- traffic_light   (gen_statem)  - Traffic Light FSM


Modules
-------

| Module              | Behaviour    | Description                              |
|---------------------|-------------|------------------------------------------|
| full_otp_app_app    | application | Application callback, starts supervisor  |
| full_otp_app_sup    | supervisor  | Top-level supervisor, one_for_one        |
| kv_server           | gen_server  | In-memory key-value store                |
| event_bus           | gen_event   | Central event bus (wraps gen_event)      |
| event_bus_handler   | gen_event   | Default handler, logs events to stdout   |
| traffic_light       | gen_statem  | Traffic light FSM (red/green/yellow)     |
| demo                | -           | Interactive demo exercising all modules  |


Build (rebar3)
--------------

    cd full_otp_app
    rebar3 compile


Run
---

    rebar3 shell

    %% The application starts automatically.
    %% Run the interactive demo:
    demo:run().


Manual Usage
------------

    %% gen_server - Key-Value Store
    kv_server:put(name, "Erlang").
    kv_server:get(name).              %% => {ok, "Erlang"}
    kv_server:delete(name).
    kv_server:all().
    kv_server:clear().

    %% gen_event - Event Bus
    event_bus:notify({info, "hello"}).
    event_bus:which_handlers().

    %% gen_statem - Traffic Light
    traffic_light:current_state().    %% => red | green | yellow
    traffic_light:next().             %% manually advance
    traffic_light:emergency().        %% force red
    traffic_light:resume().           %% resume auto-transition

    %% Supervisor
    supervisor:which_children(full_otp_app_sup).
    supervisor:count_children(full_otp_app_sup).
