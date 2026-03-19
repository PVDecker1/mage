---
name: simulink
description: Programmatically build, configure, and simulate Simulink models. Use for adding/connecting blocks, setting parameters, and managing simulations.
license: MIT (see LICENSE)
metadata:
  author: Austin Decker
  version: "1.0"
---

# MATLAB Simulink Programmatic Modeling

## Must-Follow Rules

- **Never hardcode block library paths** — Display names in the Library Browser are not valid `add_block` arguments. They contain newlines and special characters. Always resolve paths dynamically with `findBlock()`. See Block Path Resolution.
- **Never call `clear` in a model-building script** — It destroys caller workspace variables and crashes tool runners. Use `bdclose(modelName)` to reset Simulink state.
- **Never set `InitialCondition` via `set_param` during a running simulation** — All initial conditions must be set before `sim()` is called. Doing this at runtime causes solver instability.
- **Never connect lines with string port paths** — Paths like `'Velocity/2'` or `'Velocity/R'` break silently when Reset or IC ports are enabled. Use `PortHandles` exclusively. See Connecting Lines.
- **Never set port count on a MATLAB Function block via `set_param`** — Port count is determined solely by the function signature in `block.Script`. Set the script first, then connect lines.
- **Do not guess block paths or parameter enum strings** — If uncertain, use `get_param` to inspect the library. See Troubleshooting.

---

## Block Path Resolution

Block display names are not valid `add_block` arguments. Use `BlockType` to resolve paths dynamically. Add `findBlock` as a local function in every model-building script.

```matlab
function path = findBlock(blockType)
% Resolves the correct library path for a block by its internal BlockType.
% Immune to display name formatting (newlines, ampersands, etc.).
    load_system('simulink');
    results = find_system('simulink', ...
        'LookUnderMasks', 'all', ...
        'FollowLinks',    'on',  ...
        'BlockType',      blockType);
    if isempty(results)
        error('simulink:blockNotFound', ...
              'No block with BlockType "%s". Inspect the library with get_param.', blockType);
    end
    path = results{1};
end
```

Resolve all paths once at the top of the script:

```matlab
integPath    = findBlock('Integrator');
gainPath     = findBlock('Gain');
constPath    = findBlock('Constant');
hitCrossPath = findBlock('HitCross');
muxPath      = findBlock('Mux');
selectorPath = findBlock('Selector');
scopePath    = findBlock('Scope');
```

### BlockType Reference

| Display Name | BlockType | Library |
| :--- | :--- | :--- |
| Sine Wave | `Sin` | Sources |
| Constant | `Constant` | Sources |
| Step | `Step` | Sources |
| Integrator | `Integrator` | Continuous |
| Derivative | `Derivative` | Continuous |
| Transfer Fcn | `TransferFcn` | Continuous |
| Gain | `Gain` | Math Operations |
| Sum | `Sum` | Math Operations |
| Product | `Product` | Math Operations |
| Trigonometric Function | `Trigonometry` | Math Operations |
| Mux | `Mux` | Signal Routing |
| Demux | `Demux` | Signal Routing |
| Selector | `Selector` | Signal Routing |
| Bus Creator | `BusCreator` | Signal Routing |
| Switch | `Switch` | Signal Routing |
| Scope | `Scope` | Sinks |
| XY Graph | `XYGraph` | Sinks |
| Outport | `Outport` | Ports & Subsystems |
| MATLAB Function | `SubSystem` | User-Defined Functions |
| Hit Crossing | `HitCross` | Discontinuities |
| Relational Operator | `RelationalOperator` | Logic and Bit Operations |

If a block is not in this table, inspect the library directly — do not guess:

```matlab
load_system('simulink');
get_param('simulink/Discontinuities', 'Blocks')              % list display names
get_param('simulink/Discontinuities/Dead Zone', 'BlockType') % get BlockType
```

---

## Model Initialization

Always follow this sequence. The `bdIsLoaded` guard prevents errors on re-runs.

```matlab
modelName = 'MyModel';

if bdIsLoaded(modelName)
    bdclose(modelName);
end

new_system(modelName);
load_system(modelName);     % safer than open_system for scripting

% Set solver before adding blocks
set_param(modelName, 'StopTime',   '30');
set_param(modelName, 'SolverType', 'Variable-step');
set_param(modelName, 'Solver',     'ode45');
set_param(modelName, 'MaxStep',    '0.01');  % keep small for event detection
```

---

## Setting Block Parameters

`set_param` requires literal strings — not MATLAB variable names or numeric values.

```matlab
% WRONG
set_param(blk, 'InitialCondition', 'my_vec');   % fails if not in model workspace
set_param(blk, 'Gain', myGainVariable);          % wrong type

% RIGHT
set_param(blk, 'InitialCondition', mat2str(val));                          % '[10 0]'
set_param(blk, 'Gain',             num2str(gain));                         % '9.81'
set_param(blk, 'InitialCondition', sprintf('[%.6f, %.6f]', val(1), val(2)));
```

### Parameter Enum Reference

| Block | Parameter | Valid Strings |
| :--- | :--- | :--- |
| Switch | `Criteria` | `'u2 > Threshold'`, `'u2 >= Threshold'`, `'u2 ~= 0'` |
| Integrator | `ExternalReset` | `'none'`, `'rising'`, `'falling'`, `'either'`, `'level'`, `'level hold'` |
| Integrator | `InitialConditionSource` | `'internal'`, `'external'` |
| Relational Operator | `Operator` | `'=='`, `'~='`, `'<'`, `'<='`, `'>'`, `'>='` |
| Hit Crossing | `HitCrossingDirection` | `'rising'`, `'falling'`, `'either'` |
| Selector | `Elements` | `'1'`, `'2'`, `'[1 2]'` (1-based, as string) |

---

## Connecting Lines

Always use `PortHandles`. String port paths (`'Block/2'`, `'Block/R'`) are fragile — port numbers shift when Reset or IC ports are enabled.

```matlab
% WRONG — breaks silently when reset ports are added
add_line(modelName, 'Velocity/1', 'Position/1');
add_line(modelName, 'HitCross/1', 'Velocity/2');

% RIGHT
ph_vel = get_param(hVelocity, 'PortHandles');
ph_pos = get_param(hPosition, 'PortHandles');
ph_hit = get_param(hHitCross, 'PortHandles');

add_line(modelName, ph_vel.Outport(1), ph_pos.Inport(1),       'autorouting', 'on');
add_line(modelName, ph_hit.Outport(1), ph_vel.Reset,            'autorouting', 'on');
add_line(modelName, ph_ic.Outport(1),  ph_vel.InitialCondition, 'autorouting', 'on');
```

### PortHandles Fields

| Field | When present |
| :--- | :--- |
| `.Inport(n)` | Always |
| `.Outport(n)` | Always |
| `.Reset` | `ExternalReset ~= 'none'` |
| `.InitialCondition` | `InitialConditionSource == 'external'` |
| `.Enable` | Enable subsystems |
| `.Trigger` | Triggered subsystems |

---

## State Reset Pattern (Bouncing / Collision)

Use the integrator external reset pattern for any state discontinuity (bounce, collision, contact). **Do not use a Switch block feeding back into an integrator input** — this creates algebraic loops and is physically incorrect.

The pattern:
1. Set `ExternalReset = 'rising'` and `InitialConditionSource = 'external'` on the velocity integrator
2. Use a Hit Crossing block (`HitCrossingDirection = 'falling'`) to detect ground contact
3. Wire the Hit Crossing output to the integrator's `.Reset` port
4. Wire the post-bounce velocity (velocity × restitution gain) to the integrator's `.InitialCondition` port

```matlab
% --- Blocks ---
hVyInt  = add_block(integPath,    [modelName '/Y_Vel']);
hYPos   = add_block(integPath,    [modelName '/Y_Pos']);
hGrav   = add_block(constPath,    [modelName '/Gravity']);
hHit    = add_block(hitCrossPath, [modelName '/GroundHit']);
hRestit = add_block(gainPath,     [modelName '/Restitution']);

set_param(hVyInt, 'InitialCondition',       num2str(vy0), ...
                  'ExternalReset',          'rising',     ...
                  'InitialConditionSource', 'external');
set_param(hYPos,   'InitialCondition',      num2str(y0));
set_param(hGrav,   'Value',                 '-9.81');
set_param(hHit,    'HitCrossingOffset',     '0',          ...
                   'HitCrossingDirection',  'falling');
set_param(hRestit, 'Gain',                  '-0.8');

% --- Connections via PortHandles ---
ph_vyint  = get_param(hVyInt,  'PortHandles');
ph_ypos   = get_param(hYPos,   'PortHandles');
ph_grav   = get_param(hGrav,   'PortHandles');
ph_hit    = get_param(hHit,    'PortHandles');
ph_restit = get_param(hRestit, 'PortHandles');

add_line(modelName, ph_grav.Outport(1),   ph_vyint.Inport(1),        'autorouting', 'on');
add_line(modelName, ph_vyint.Outport(1),  ph_ypos.Inport(1),         'autorouting', 'on');
add_line(modelName, ph_ypos.Outport(1),   ph_hit.Inport(1),          'autorouting', 'on');
add_line(modelName, ph_hit.Outport(1),    ph_vyint.Reset,             'autorouting', 'on');
add_line(modelName, ph_vyint.Outport(1),  ph_restit.Inport(1),       'autorouting', 'on');
add_line(modelName, ph_restit.Outport(1), ph_vyint.InitialCondition, 'autorouting', 'on');
```

---

## Integrator Chains for Multi-Axis Dynamics

Use one integrator per axis per derivative level. Never use a single multi-dimensional integrator — it makes port management fragile.

```matlab
% X axis — constant velocity, no acceleration
hXVel = add_block(integPath, [modelName '/X_Vel']);
hXPos = add_block(integPath, [modelName '/X_Pos']);
set_param(hXVel, 'InitialCondition', num2str(vx0));
set_param(hXPos, 'InitialCondition', '0');

% Y axis — gravity driven, with bounce reset (see State Reset Pattern)
hYVel = add_block(integPath, [modelName '/Y_Vel']);
hYPos = add_block(integPath, [modelName '/Y_Pos']);
set_param(hYVel, 'InitialCondition',       num2str(vy0), ...
                 'ExternalReset',          'rising',     ...
                 'InitialConditionSource', 'external');
set_param(hYPos, 'InitialCondition', num2str(y0));
```

---

## MATLAB Function Block

Use for logic too complex to express with standard blocks. **Set `block.Script` before connecting any lines** — ports are created by the function signature, not by `set_param`.

```matlab
hFunc = add_block('simulink/User-Defined Functions/MATLAB Function', ...
    [modelName '/MyLogic']);

% Step 1: set script first — creates input/output ports
sf = sfroot;
blockObj = sf.find('Path', [modelName '/MyLogic'], '-isa', 'Stateflow.EMChart');
blockObj.Script = sprintf([ ...
    'function y = MyLogic(u1, u2)\n' ...
    '    y = u1 + u2;\n'             ...
    'end']);

% Step 2: get port handles — only valid after script is set
ph_func = get_param(hFunc, 'PortHandles');

% Step 3: connect
add_line(modelName, ph_source1.Outport(1), ph_func.Inport(1), 'autorouting', 'on');
add_line(modelName, ph_source2.Outport(1), ph_func.Inport(2), 'autorouting', 'on');
```

Do not use `persistent` variables inside a MATLAB Function block to track physics state — they do not reset reliably between `sim()` calls. Use an Integrator block for state instead.

---

## Full Script Template

```matlab
function create_my_model()
% CREATE_MY_MODEL  Builds and runs a Simulink model programmatically.
% Do not call clear() — it destroys caller workspace variables.

    modelName = 'my_model';

    % Guard
    if bdIsLoaded(modelName), bdclose(modelName); end

    % Resolve all block paths up front — never hardcode these
    integPath    = findBlock('Integrator');
    gainPath     = findBlock('Gain');
    constPath    = findBlock('Constant');
    hitCrossPath = findBlock('HitCross');
    muxPath      = findBlock('Mux');
    selectorPath = findBlock('Selector');
    scopePath    = findBlock('Scope');

    % Create and configure
    new_system(modelName);
    load_system(modelName);
    set_param(modelName, 'StopTime', '10', 'SolverType', 'Variable-step', ...
              'Solver', 'ode45', 'MaxStep', '0.01');

    % Add blocks
    % hBlock = add_block(resolvedPath, [modelName '/Name']);
    % set_param(hBlock, 'Param', num2str(value));

    % Connect via PortHandles
    % ph = get_param(hBlock, 'PortHandles');
    % add_line(modelName, ph_a.Outport(1), ph_b.Inport(1), 'autorouting', 'on');

    % Save and run
    save_system(modelName, [modelName '.slx']);
    sim(modelName);
    close_system(modelName);
    disp(['Done. Saved ' modelName '.slx']);
end


function path = findBlock(blockType)
    load_system('simulink');
    results = find_system('simulink', 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'BlockType', blockType);
    if isempty(results)
        error('simulink:blockNotFound', ...
              'No block with BlockType "%s". Use get_param to inspect.', blockType);
    end
    path = results{1};
end
```

---

## Troubleshooting

**"There is no block named 'simulink/X/Y'"**
Do not guess the correct name. Inspect the library:
```matlab
load_system('simulink');
get_param('simulink/Discontinuities', 'Blocks')               % list display names
get_param('simulink/Discontinuities/Dead Zone', 'BlockType')  % get BlockType for findBlock
```

**"Invalid Simulink object name: 'BlockName/2'"**
You are using string port paths. Switch to `PortHandles` — see Connecting Lines.

**"Error due to multiple causes" from `sim()`**
Usually an algebraic loop or unconnected port. Check:
- Every input port has exactly one incoming connection
- No direct feedback loop without an integrator or delay in the path
- Bounce logic uses the State Reset Pattern, not Switch feedback into an integrator input

**"Reference to a cleared variable" in tool runner**
The script called `clear`. Remove it. Use `bdclose(modelName)` instead.

**"SubSystem block does not have a parameter named 'Inputs'"**
Port count on a MATLAB Function block cannot be set via `set_param`. Set `block.Script` with the correct function signature — ports are created automatically.

**Simulation runs but bounce has no effect**
- `ExternalReset` must be `'rising'`, `HitCrossingDirection` must be `'falling'`
- Restitution gain output must connect to `.InitialCondition`, not an `.Inport`
- `MaxStep` must be small enough to catch the crossing event (`0.01` or less)