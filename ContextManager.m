classdef ContextManager < handle
    % ContextManager Manages multi-tiered context for MATL-AGENT.
    %   T1: Project config (always stays)
    %   T2: Session state (summarized across compactions)
    %   T3: In-memory conversation (gets auto-compacted when full)
    %   T4: Retrieved files/knowledge (injected per-turn)

    events
        ContextCompacted
    end

    properties
        Config        % Token limits and other settings
        Agent         % Reference to AgentLoop
        T1_Config     % struct or array containing AGENT.md / config.json content
        T2_Session    % struct managing .agent/session.json state
        T3_Conversation % cell array of turn dicts/structs (OpenAI msg format)
        T4_Retrieved  % struct mapping file paths -> text content for the turn
        TokenBudget   % Max context tokens before forcing a handoff
        CompactionThresh % Ratio to trigger compaction (e.g., 0.70)
    end

    methods
        function obj = ContextManager(cfg, agent)
            % ContextManager Constructor.
            %   Initializes the tiered context based on config limits.

            if nargin < 1
                cfg = struct();
            end
            if nargin < 2
                agent = [];
            end

            obj.Config = cfg;
            obj.Agent = agent;

            % Setup defaults if not provided in config
            if isfield(cfg, 'context_budget')
                obj.TokenBudget = cfg.context_budget;
            else
                obj.TokenBudget = 100000;
            end

            if isfield(cfg, 'compact_threshold')
                obj.CompactionThresh = cfg.compact_threshold;
            else
                obj.CompactionThresh = 0.70;
            end

            obj.T1_Config = {};
            obj.T2_Session = struct('ledger', '', 'open_files', {{}}, 'branch', 'main');
            obj.T3_Conversation = {};
            obj.T4_Retrieved = struct();
            
            % Try to load session if exists
            obj.loadSession();
        end

        function loadSession(obj)
            % loadSession Loads existing T2 session state from .agent/session.json
            sessionPath = fullfile(pwd, '.agent', 'session.json');
            if isfile(sessionPath)
                try
                    txt = fileread(sessionPath);
                    obj.T2_Session = jsondecode(txt);
                catch
                    % Fallback to fresh session
                end
            end
        end

        function push(obj, messageStruct)
            % push Append a message to the T3 conversation history.
            %   messageStruct must follow OpenAI format (role, content).

            if ~isstruct(messageStruct) || ~isfield(messageStruct, 'role')
                error('matl_agent:ContextManager:invalidFormat', 'Message must be a struct with at least a role field.');
            end
            
            % Allow missing content if tool_calls or tool_call_id is present
            if ~isfield(messageStruct, 'content') && ...
               ~isfield(messageStruct, 'tool_calls') && ...
               ~isfield(messageStruct, 'tool_call_id')
                error('matl_agent:ContextManager:missingContent', 'Message must have content unless it is a tool call/result.');
            end

            % Ensure content field exists for consistency if it's missing
            if ~isfield(messageStruct, 'content')
                messageStruct.content = '';
            end

            obj.T3_Conversation{end+1} = messageStruct;
            obj.maybeCompact();
        end

        function maybeCompact(obj)
            % maybeCompact Checks if token estimate exceeds threshold and triggers compaction.

            currentEstimate = obj.estimateTokens();
            thresholdTokens = obj.TokenBudget * obj.CompactionThresh;

            if currentEstimate >= thresholdTokens
                % Perform pseudo-compaction by summarizing T3 into T2
                summary = sprintf('Compacted %d turns on %s.', length(obj.T3_Conversation), datestr(now));
                obj.T2_Session.ledger = [obj.T2_Session.ledger, newline, summary];
                obj.T3_Conversation = {}; % Clear conversation to reset budget
                
                obj.saveSession();
                
                % Fire event on itself
                notify(obj, 'ContextCompacted', AgentEventData(struct('message', summary)));
                
                % If we have a reference to the agent, fire there too for UI listeners
                if ~isempty(obj.Agent)
                    notify(obj.Agent, 'ContextCompacted', AgentEventData(struct('message', summary)));
                end
            end
        end

        function saveSession(obj)
            % saveSession Persists the T2_Session state to .agent/session.json.
            
            agentFolder = fullfile(pwd, '.agent');
            if ~isfolder(agentFolder), mkdir(agentFolder); end
            
            sessionPath = fullfile(agentFolder, 'session.json');
            try
                fid = fopen(sessionPath, 'w');
                if fid ~= -1
                    fprintf(fid, '%s', jsonencode(obj.T2_Session));
                    fclose(fid);
                end
            catch
                % Fail silently on save errors
            end
        end

        function tokens = estimateTokens(obj)
            % estimateTokens Returns a rough estimate of the current token usage.
            %   Calculated via simple heuristics (e.g., 1 token per 4 chars).

            totalChars = 0;

            % Estimate T1 chars
            for i = 1:length(obj.T1_Config)
                if isfield(obj.T1_Config{i}, 'content')
                    totalChars = totalChars + length(obj.T1_Config{i}.content);
                end
            end

            % Estimate T2 chars
            totalChars = totalChars + length(obj.T2_Session.ledger);

            % Estimate T3 chars
            for i = 1:length(obj.T3_Conversation)
                msg = obj.T3_Conversation{i};
                if ischar(msg.content)
                    totalChars = totalChars + length(msg.content);
                end
                % Account for tool call metadata (rough estimate)
                if isfield(msg, 'tool_calls') && ~isempty(msg.tool_calls)
                    totalChars = totalChars + 200; 
                end
                if isfield(msg, 'tool_call_id')
                    totalChars = totalChars + 50;
                end
            end

            % Estimate T4 chars
            fields = fieldnames(obj.T4_Retrieved);
            for i = 1:length(fields)
                totalChars = totalChars + length(obj.T4_Retrieved.(fields{i}));
            end

            % Simple approximation: 4 chars per token
            tokens = round(totalChars / 4);
        end
    end
end
