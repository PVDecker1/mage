classdef LLMClient < handle
    % LLMClient A generic HTTP client for OpenAI-compatible LLM endpoints.
    %   Used by MATL-AGENT for chat completions. Never hardcodes credentials.

    properties
        Config      % struct holding configuration (URL, model, secrets)
        BaseURL     % endpoint URL (e.g., https://api.openai.com/v1/chat/completions)
        Model       % model ID string
        ApiKey      % token/API key read from config or env
    end

    methods
        function obj = LLMClient(cfg)
            % LLMClient Constructor initializing the client with given config.
            %   Reads endpoint, model, and secrets. Falls back to getenv.

            if nargin < 1
                cfg = struct();
            end

            obj.Config = cfg;

            % Resolve Endpoint
            if isfield(cfg, 'endpoint')
                obj.BaseURL = cfg.endpoint;
            else
                obj.BaseURL = 'https://generativelanguage.googleapis.com/v1beta/openai/'; % Default to Gemini
            end

            % Resolve Model
            if isfield(cfg, 'model')
                obj.Model = cfg.model;
            else
                obj.Model = 'gemini-2.5-pro';
            end

            % Resolve API Key
            obj.ApiKey = '';
            if isfield(cfg, 'secrets') && isfield(cfg.secrets, 'api_key')
                obj.ApiKey = cfg.secrets.api_key;
            else
                obj.ApiKey = getenv('MATL_AGENT_API_KEY');
            end

            if isempty(obj.ApiKey)
                % Not throwing an error immediately; wait for a chat call.
                % Some endpoints (like local Ollama) might not require one.
            end
        end

        function response = chatCompletion(obj, messages, tools)
            % chatCompletion Sends a POST request to the LLM endpoint.
            %   messages is a cell array of structs (role, content).
            %   tools is an optional struct defining available functions.

            if isempty(obj.ApiKey) && ~contains(obj.BaseURL, 'localhost')
                error('matl_agent:LLMClient:missingKey', 'API key not found in config or MATL_AGENT_API_KEY env var.');
            end

            % Setup payload
            payload = struct();
            payload.model = obj.Model;
            payload.messages = messages;

            if nargin > 2 && ~isempty(tools)
                payload.tools = tools;
            end

            % Configure headers via weboptions
            options = weboptions('MediaType', 'application/json', ...
                                 'Timeout', 60);

            if ~isempty(obj.ApiKey)
                options.HeaderFields = {'Authorization', ['Bearer ' obj.ApiKey]};
            end

            % Format URL for chat completions endpoint if needed
            url = obj.BaseURL;
            if ~endsWith(url, 'chat/completions')
                if endsWith(url, '/')
                    url = [url, 'chat/completions'];
                else
                    url = [url, '/chat/completions'];
                end
            end

            % Make HTTP POST
            try
                response = webwrite(url, payload, options);
            catch ME
                error('matl_agent:LLMClient:httpError', 'HTTP request failed: %s', ME.message);
            end
        end
    end
end
