classdef AgentEventData < event.EventData
    % AgentEventData Custom event data class for Mage events
    %   Used to pass structured payloads (like text, tool call info, or errors)
    %   from the AgentLoop to subscribed UI adapters like CmdWindowAdapter.

    properties
        Data     % Struct containing the event payload (e.g., text, name, message)
        Response % Place for listeners to store a return value (e.g., user response)
    end

    methods
        function obj = AgentEventData(dataStruct)
            % AgentEventData Constructor for the event data.
            %   obj = AgentEventData(dataStruct) creates an event data object
            %   carrying the provided data struct.

            if nargin > 0
                obj.Data = dataStruct;
            else
                obj.Data = struct();
            end
        end
    end
end
