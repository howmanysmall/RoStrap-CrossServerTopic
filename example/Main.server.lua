local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Resources = require(ReplicatedStorage:WaitForChild("Resources"))

local CrossServerTopic = Resources:LoadLibrary("CrossServerTopic")

local PlayerEnteredGame = CrossServerTopic.new("PlayerEnteredGame")
-- PlayerEnteredGame.RemoteMessagesOnly = true

PlayerEnteredGame.MessageRecieved:Connect(function (message, fromRemote, timeSent)
    print(("Player %s entered game. Time Sent: %.2f %s")
        :format(message, timeSent, (fromRemote and "Recieved From Remote" or "Recieved From Self")))
end)

PlayerEnteredGame:Subscribe()

game.Players.PlayerAdded:Connect(function (ply)
    PlayerEnteredGame:Send(ply.Name)
end)