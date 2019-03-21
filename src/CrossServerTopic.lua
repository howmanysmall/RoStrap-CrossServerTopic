--[[
    CrossServerTopic
        by Gamenew09

    Description:
        CrossServerTopic is an object module that allows for handling messages sent and recieved by the newly introduced MessagingService.
        CrossServerTopic isn't just a OOP wrapper of the MessagingService, it seperates the message and time sent in the Subscription Event
        and allows for deteriming if the message that was recieved was from the local server or from a remote server without you doing anything.

    Module API: (when required)
        CrossServerTopic CrossServerTopic.new(string topicName)
            Creates a new CrossServerTopic (or uses an existing CrossServerTopic if already created) object.
            Arguments:
                topicName: The name of the topic that this object is associated with.
            Returns:
                CrossServerTopic
        
    CrossServerTopic object API: (when created via .new)
        Properties:
            bool RemoteMessagesOnly:
                When set to true and subscribed to the topic via :Subscribe, it will "discard" messages sent by the server instance running the module.
            Signal MessageRecieved:
                A signal that is called when the topic recieves a message if subscribed.
                Callback Function Signature:
                    void(Variant message, bool fromRemote, number timeSent)
                        message: The message that was recieved by the topic.
                        fromRemote: When true, it indicates that the message originated from a server other than the one we are running this module on.
                        timeSent: The time that the message was sent.
        
        Functions:
            void CrossServerTopic:Send(Variant message)
                Sends the message provided (with some extra data for the api that is needed) over the MessagingService.
                Arguments:
                    message: The message that the other servers will recieve.
            bool CrossServerTopic:IsSubscribed()
                Returns whether or not the topic is recieving messages from the topic.
            void CrossServerTopic:Subscribe()
                If not already subscribed to the topic, it will subscribe and recieve messages, allowing for the MessageRecieved event to be called.
            void CrossServerTopic:Unsubscribe()
                If subscribed to the topic, it will unsubscribe and stop recieving messages (making the MessageRecieved event not useful until Calling :Subscribe() again)
            void CrossServerTopic:Destroy()
                Alias to CrossServerTopic:Unsubscribe()

    Example:
        local PlayerEnteredGame = CrossServerTopic.new("PlayerEnteredGame")

        PlayerEnteredGame.MessageRecieved:Connect(function (message, fromRemote, timeSent)
            print(("Player %s entered game. Time Sent: %.2f %s")
                :format(message, timeSent, (fromRemote and "Recieved From Remote" or "Recieved From Self")))
        end)

        PlayerEnteredGame:Subscribe()

        game.Players.PlayerAdded:Connect(function (ply)
            PlayerEnteredGame:Send(ply.Name)
        end)
--]]

-- Roblox Services

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RoStrap Resources --

local Resources = require(ReplicatedStorage:WaitForChild("Resources"))

-- Libraries --

local Signal = Resources:LoadLibrary("Signal")

-- CrossServerTopic --

local WARN_WHEN_USING_FUNCTIONS_IN_STUDIO = true
local IS_ONLINE = not game:GetService("RunService"):IsStudio()

local ServerTopicCache = {}

local CrossServerTopic = {}
CrossServerTopic.__index = CrossServerTopic

function CrossServerTopic.new(topicName)
    if not ServerTopicCache[topicName] then
        local self = setmetatable({
            ["Topic"] = topicName,
            ["MessageRecieved"] = Signal.new(), -- (message, timeSent, fromRemote) message: The message that was recieved (either via MessagingService or locally via Send). fromRemote: Will be true if the message originates from MessagingService and not from calling Send. timeSent: The time that the originating server sent the message.
            ["RemoteMessagesOnly"] = false,

            ["_SubscriptionEvent"] = nil
        }, CrossServerTopic)
        
        ServerTopicCache[topicName] = self
    end

    return ServerTopicCache[topicName]
end

function CrossServerTopic:Send(message)
    assert(message ~= nil, "message must not be nil")

    local underlyingMessage = {
        ["Message"] = message,
        ["OriginatingServerJobId"] = game.JobId -- Allows us to compare and see if this is a local message when it is recieved.
        -- In the future, allowing for sending "directly" to a server
    }

    if IS_ONLINE then
        MessagingService:PublishAsync(self.Topic, underlyingMessage)
    elseif WARN_WHEN_USING_FUNCTIONS_IN_STUDIO then
        warn(("Cannot send message to topic \"%s\". MessagingService does not work in studio. Ignoring call."):format(self.Topic))
    end
end

function CrossServerTopic:IsSubscribed()
    return self._SubscriptionEvent ~= nil
end

function CrossServerTopic:Subscribe()
    if not IS_ONLINE and WARN_WHEN_USING_FUNCTIONS_IN_STUDIO then
        warn(("Cannot subscribe to topic \"%s\". MessagingService does not work in studio. Ignoring call."):format(self.Topic))
    else
        if not self:IsSubscribed() then
            self._SubscriptionEvent = MessagingService:SubscribeAsync(self.Topic, function (messageTable)
                local underlyingMessage = messageTable.Data
                local timeSent = messageTable.Sent
                local fromRemote = (underlyingMessage.OriginatingServerJobId ~= game.JobId)
    
                if fromRemote or not self.RemoteMessagesOnly then
                    self.MessageRecieved:Fire(underlyingMessage.Message, fromRemote, timeSent)
                end
            end)
        end
    end
end

function CrossServerTopic:Unsubscribe()
    if not IS_ONLINE and WARN_WHEN_USING_FUNCTIONS_IN_STUDIO then
        warn(("Cannot unsubscribe from topic \"%s\". MessagingService does not work in studio. Ignoring call."):format(self.Topic))
    else
        if self:IsSubscribed() then -- If we are subscribed to the topic via MessagingService:SubscribeAsync, disconnect the event we have and discard it.
            self._SubscriptionEvent:Disconnect()
            self._SubscriptionEvent = nil
        end
    end
end

function CrossServerTopic:Destroy()
    self:Unsubscribe()
end

return CrossServerTopic