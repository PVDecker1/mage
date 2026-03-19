classdef LLMClient < handle
    % LLMClient Generic HTTP client for OpenAI-compatible LLM endpoints.

    properties
        Config
        BaseURL
        Model
        ApiKey
    end

    methods
        function obj = LLMClient(cfg)
            if nargin < 1 || isempty(cfg)
                error('mage:LLMClient:missingConfig', 'LLMClient requires a configuration struct.');
            end
            obj.Config = cfg;
            
            % Resolve Endpoint - Required
            if isfield(cfg, 'endpoint') && ~isempty(cfg.endpoint)
                obj.BaseURL = cfg.endpoint;
            else
                error('mage:LLMClient:missingEndpoint', 'Missing "endpoint" in config.json');
            end

            % Resolve Model - Required, trust user exactly
            if isfield(cfg, 'model') && ~isempty(cfg.model)
                obj.Model = cfg.model;
            else
                error('mage:LLMClient:missingModel', 'Missing "model" in config.json');
            end

            % Resolve API Key
            if isfield(cfg, 'secrets') && isfield(cfg.secrets, 'api_key') && ~isempty(cfg.secrets.api_key)
                obj.ApiKey = cfg.secrets.api_key;
            else
                obj.ApiKey = getenv('MAGE_API_KEY');
            end
            
            if isempty(obj.ApiKey) && ~contains(obj.BaseURL, 'localhost')
                error('mage:LLMClient:missingKey', 'API key not found in config or MAGE_API_KEY env var.');
            end
        end

        function response = chatCompletion(obj, messages, tools)
            import matlab.net.http.*
            import matlab.net.http.field.*

            % Setup payload
            payload = struct();
            payload.model = obj.Model;
            payload.messages = messages;
            if nargin > 2 && ~isempty(tools)
                payload.tools = tools;
            end

            % Format URL
            url = obj.BaseURL;
            if ~endsWith(url, '/'), url = [url '/']; end
            if ~contains(url, 'chat/completions'), url = [url 'chat/completions']; end
            
            % Add key to URL for Gemini shim compatibility
            if ~isempty(obj.ApiKey) && contains(url, 'generativelanguage.googleapis.com')
                if ~contains(url, '?'), url = [url '?key=' obj.ApiKey];
                else, url = [url '&key=' obj.ApiKey]; end
            end

            % Setup Request
            header = [HeaderField('Content-Type', 'application/json') ...
                      HeaderField('Authorization', ['Bearer ' obj.ApiKey])];
            
            % Put payload directly in MessageBody as requested
            body = MessageBody(payload);
            request = RequestMessage('POST', header, body);
            
            % Send with retry for 429
            maxRetries = 3;
            retryDelay = 2;
            for attempt = 1:maxRetries
                try
                    options = HTTPOptions('ConnectTimeout', 30);
                    resp = send(request, url, options);
                    
                    if resp.StatusCode == StatusCode.OK
                        response = resp.Body.Data;
                        return;
                    elseif resp.StatusCode == 429 && attempt < maxRetries
                        fprintf('Rate limited (429). Retrying in %d seconds...\n', retryDelay);
                        pause(retryDelay);
                        retryDelay = retryDelay * 2;
                        continue;
                    else
                        serverError = '';
                        if ~isempty(resp.Body) && ~isempty(resp.Body.Data)
                            if isstruct(resp.Body.Data) || iscell(resp.Body.Data)
                                serverError = jsonencode(resp.Body.Data);
                            else
                                serverError = char(resp.Body.Data);
                            end
                        end
                        error('mage:LLMClient:httpError', ...
                            'HTTP %d: %s\nModel: %s\nServer Response: %s', ...
                            double(resp.StatusCode), resp.StatusLine.ReasonPhrase, obj.Model, serverError);
                    end
                catch ME
                    if contains(ME.identifier, 'httpError'), rethrow(ME); end
                    error('mage:LLMClient:requestFailed', 'Request failed: %s', ME.message);
                end
            end
        end
        function models = listModels(obj)
            % listModels Fetches the list of available models from the endpoint.
            import matlab.net.http.*
            import matlab.net.http.field.*

            % Format URL for models endpoint
            url = obj.BaseURL;
            if contains(url, 'chat/completions')
                url = strrep(url, 'chat/completions', 'models');
            else
                if ~endsWith(url, '/'), url = [url '/']; end
                url = [url 'models'];
            end

            % Add key to URL for Gemini shim compatibility
            if ~isempty(obj.ApiKey) && contains(url, 'generativelanguage.googleapis.com')
                if ~contains(url, '?'), url = [url '?key=' obj.ApiKey];
                else, url = [url '&key=' obj.ApiKey]; end
            end

            % Setup Request
            header = [HeaderField('Content-Type', 'application/json') ...
                      HeaderField('Authorization', ['Bearer ' obj.ApiKey])];
            request = RequestMessage('GET', header);

            try
                options = HTTPOptions('ConnectTimeout', 30);
                resp = send(request, url, options);
                
                if resp.StatusCode == StatusCode.OK
                    data = resp.Body.Data;
                    if isfield(data, 'data')
                        % OpenAI format: could be cell array or struct array
                        if iscell(data.data)
                            models = cellfun(@(x) x.id, data.data, 'UniformOutput', false);
                        elseif isstruct(data.data)
                            models = {data.data.id};
                        else
                            models = {};
                        end
                    elseif isfield(data, 'models')
                        % Gemini direct format
                        if iscell(data.models)
                            models = cellfun(@(x) x.name, data.models, 'UniformOutput', false);
                        elseif isstruct(data.models)
                            models = {data.models.name};
                        else
                            models = {};
                        end
                    else
                        models = {};
                    end
                else
                    error('mage:LLMClient:httpError', 'HTTP %d: %s', double(resp.StatusCode), resp.StatusLine.ReasonPhrase);
                end
            catch ME
                error('mage:LLMClient:requestFailed', 'Failed to list models: %s', ME.message);
            end
        end
    end
end
