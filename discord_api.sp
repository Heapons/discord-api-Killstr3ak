#include <sourcemod>
#include <discord>
#include <SteamWorks>

#pragma tabsize 4
#pragma newdecls required
#pragma semicolon 1

/* https://discord.com/developers/docs/reference#api-versioning-api-versions */
#define API_VERSION 10
#define PLUGIN_VERSION "1.0.1"

#include "discord/Shared.sp"
#include "discord/Message.sp"
#include "discord/Reaction.sp"
#include "discord/User.sp"
#include "discord/ListenToChannel.sp"
#include "discord/Channel.sp"
#include "discord/Guild.sp"

//For rate limitation
Handle hRateLimit = null;
Handle hRateReset = null;
Handle hRateLeft = null;

public Plugin myinfo = 
{
	name = "Discord API",
	author = "Nexd @ Eternar",
	description = "This library is limited to the basic REST API that Discord provides.",
	version = PLUGIN_VERSION,
	url = "https://github.com/KillStr3aK | https://eternar.dev"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("DiscordBot.TriggerTypingIndicator", DiscordBot_TriggerTypingIndicator);
	CreateNative("DiscordBot.TriggerTypingIndicatorID", DiscordBot_TriggerTypingIndicatorID);

	CreateNative("DiscordBot.StartTimer", DiscordBot_StartTimer);

	CreateNative("DiscordBot.CreateGuild", DiscordBot_CreateGuild);
	CreateNative("DiscordBot.GetGuild", DiscordBot_GetGuild);
	CreateNative("DiscordBot.GetGuildMember", DiscordBot_GetGuildMember);
	CreateNative("DiscordBot.GetGuildMemberID", DiscordBot_GetGuildMemberID);
	
	CreateNative("DiscordBot.GetGuildScheduledEvent", DiscordBot_GetGuildScheduledEvent);
	CreateNative("DiscordBot.DeleteGuildScheduledEvent", DiscordBot_DeleteGuildScheduledEvent);

	CreateNative("DiscordBot.AddRole", DiscordBot_AddRole);
	CreateNative("DiscordBot.RemoveRole", DiscordBot_RemoveRole);

	CreateNative("DiscordBot.AddRoleID", DiscordBot_AddRoleID);
	CreateNative("DiscordBot.RemoveRoleID", DiscordBot_RemoveRoleID);

	CreateNative("DiscordBot.CreateDM", DiscordBot_CreateDM);
	CreateNative("DiscordBot.CreateDMID", DiscordBot_CreateDMID);

	CreateNative("DiscordBot.ModifySelf", DiscordBot_ModifySelf);

	CreateNative("DiscordBot.GetChannel", DiscordBot_GetChannel);
	CreateNative("DiscordBot.GetChannelMessages", DiscordBot_GetChannelMessages);
	CreateNative("DiscordBot.GetChannelMessagesID", DiscordBot_GetChannelMessagesID);
	CreateNative("DiscordBot.GetChannelMessage", DiscordBot_GetChannelMessage);
	CreateNative("DiscordBot.GetChannelMessageID", DiscordBot_GetChannelMessageID);

	CreateNative("DiscordBot.DeleteChannel", DiscordBot_DeleteChannel);
	CreateNative("DiscordBot.DeleteChannelID", DiscordBot_DeleteChannelID);

	CreateNative("DiscordBot.ModifyChannel", DiscordBot_ModifyChannel);
	CreateNative("DiscordBot.ModifyChannelID", DiscordBot_ModifyChannelID);

	CreateNative("DiscordBot.SendMessageToChannel", DiscordBot_SendMessageToChannel);
	CreateNative("DiscordBot.SendMessageToChannelID", DiscordBot_SendMessageToChannelID);

	CreateNative("DiscordBot.EditMessage", DiscordBot_EditMessage);
	CreateNative("DiscordBot.EditMessageID", DiscordBot_EditMessageID);

	CreateNative("DiscordBot.PinMessage", DiscordBot_PinMessage);
	CreateNative("DiscordBot.PinMessageID", DiscordBot_PinMessageID);

	CreateNative("DiscordBot.UnpinMessage", DiscordBot_UnpinMessage);
	CreateNative("DiscordBot.UnpinMessageID", DiscordBot_UnpinMessageID);

	CreateNative("DiscordBot.GetPinnedMessages", DiscordBot_GetPinnedMessages);
	CreateNative("DiscordBot.GetPinnedMessagesID", DiscordBot_GetPinnedMessagesID);

	CreateNative("DiscordBot.CrosspostMessage", DiscordBot_CrosspostMessage);

	CreateNative("DiscordBot.DeleteMessagesBulk", DiscordBot_DeleteMessagesBulk);
	CreateNative("DiscordBot.DeleteMessage", DiscordBot_DeleteMessage);
	CreateNative("DiscordBot.DeleteMessageID", DiscordBot_DeleteMessageID);
	
	CreateNative("DiscordBot.CreateReaction", DiscordBot_CreateReaction);
	CreateNative("DiscordBot.CreateReactionID", DiscordBot_CreateReactionID);

	CreateNative("DiscordBot.DeleteOwnReaction", DiscordBot_DeleteOwnReaction);
	CreateNative("DiscordBot.DeleteOwnReactionID", DiscordBot_DeleteOwnReactionID);

	CreateNative("DiscordBot.DeleteReaction", DiscordBot_DeleteReaction);
	CreateNative("DiscordBot.DeleteReactionID", DiscordBot_DeleteReactionID);

	CreateNative("DiscordBot.DeleteAllReactions", DiscordBot_DeleteAllReactions);
	CreateNative("DiscordBot.DeleteAllReactionsID", DiscordBot_DeleteAllReactionsID);

	CreateNative("DiscordBot.DeleteAllReactionsEmoji", DiscordBot_DeleteAllReactionsEmoji);
	CreateNative("DiscordBot.DeleteAllReactionsEmojiID", DiscordBot_DeleteAllReactionsEmojiID);
	
	CreateNative("DiscordAPI_Version", Native_Version);
	
	RegPluginLibrary("Discord-API");
	return APLRes_Success;
}

public int Native_Version(Handle plugin, int numParams)
{
	char sBuffer[16];
	Format(sBuffer, 16, "%s", PLUGIN_VERSION);
	
	ReplaceString(sBuffer, 16, ".", "");
	
	return StringToInt(sBuffer);
}

public void OnPluginStart()
{
	hRateLeft = new StringMap();
	hRateReset = new StringMap();
	hRateLimit = new StringMap();
}

void SendRequest(DiscordBot bot, const char[] route, JSON_Object json = null, EHTTPMethod method = k_EHTTPMethodGET, SteamWorksHTTPDataReceived OnDataReceivedCb = INVALID_FUNCTION, SteamWorksHTTPRequestCompleted OnRequestCompletedCb = INVALID_FUNCTION, any data1 = 0, any data2 = 0)
{
	if(OnRequestCompletedCb == INVALID_FUNCTION)
	{
		OnRequestCompletedCb = OnHTTPRequestComplete; // include/discord/DiscordRequest.inc#L8
	}
	
	if(OnDataReceivedCb == INVALID_FUNCTION)
	{
		OnDataReceivedCb = OnHTTPDataReceive; // include/discord/DiscordRequest.inc#L10
	}

	char szEndpoint[512];
	Format(szEndpoint, sizeof(szEndpoint), "https://discord.com/api/v%i/%s", API_VERSION, route);

	DiscordRequest request = new DiscordRequest(szEndpoint, method);
	
	if(bot != null)
	{
		request.SetBot(bot);
	}
	request.SetJsonBody(json);
	request.Timeout = 30;
	request.SetCallbacks(OnRequestCompletedCb, OnHeadersReceivedCb, OnDataReceivedCb);
	if(data2 != 0)
	{
		request.SetContextValue(data1, data2);
	}
	else
	{
		request.SetContextData(data1, route);
	}
	request.SetContentSize();
	
	SendDiscordRequest(request, route);
}

void SendDiscordRequest(DiscordRequest request, const char[] route)
{
	int time = GetTime();
	int resetTime;
	
	int defLimit = 0;
	if(!GetTrieValue(hRateLimit, route, defLimit))
	{
		defLimit = 1;
	}
	
	bool exists = GetTrieValue(hRateReset, route, resetTime);
	
	if(!exists)
	{
		SetTrieValue(hRateReset, route, GetTime() + 5);
		SetTrieValue(hRateLeft, route, defLimit - 1);
		request.Send();
		return;
	}
	
	if(time == -1)
	{
		//No x-rate-limit send
		request.Send();
		return;
	}
	
	if(time > resetTime)
	{
		SetTrieValue(hRateLeft, route, defLimit - 1);
		request.Send();
		return;
	}
	else
	{
		int left;
		GetTrieValue(hRateLeft, route, left);
		if(left == 0)
		{
			float remaining = float(resetTime) - float(time) + 1.0;
			if(remaining < 1.0)
			{
				remaining = 1.0;
			}
			DataPack dp = new DataPack();
			dp.WriteCell(request);
			dp.WriteString(route);
			CreateTimer(remaining, SendRequestAgain, dp);
		}
		else
		{
			left--;
			SetTrieValue(hRateLeft, route, left);
			request.Send();
		}
	}
}

public Action SendRequestAgain(Handle timer, DataPack dp)
{
	dp.Reset();
	DiscordRequest request = view_as<DiscordRequest>(dp.ReadCell());
	char route[128];
	dp.ReadString(route, 128);
	delete dp;
	SendDiscordRequest(request, route);
}

public int OnHeadersReceivedCb(Handle request, bool failure, any data, any datapack)
{
	DataPack dp = view_as<DataPack>(datapack);
	
	if(failure)
	{
		delete dp;
		return;
	}
	
	char xRateLimit[16];
	char xRateLeft[16];
	char xRateReset[32];
	
	bool exists = false;
	
	exists = SteamWorks_GetHTTPResponseHeaderValue(request, "X-RateLimit-Limit", xRateLimit, sizeof(xRateLimit));
	exists = SteamWorks_GetHTTPResponseHeaderValue(request, "X-RateLimit-Remaining", xRateLeft, sizeof(xRateLeft));
	exists = SteamWorks_GetHTTPResponseHeaderValue(request, "X-RateLimit-Reset", xRateReset, sizeof(xRateReset));
	
	//Get url
	char route[128];
	dp.Reset();
	dp.ReadString(route, sizeof(route));
	delete dp;
	
	int reset = StringToInt(xRateReset);
	if(reset > GetTime() + 3)
	{
		reset = GetTime() + 3;
	}
	
	if(exists)
	{
		SetTrieValue(hRateReset, route, reset);
		SetTrieValue(hRateLeft, route, StringToInt(xRateLeft));
		SetTrieValue(hRateLimit, route, StringToInt(xRateLimit));
	}
	else
	{
		SetTrieValue(hRateReset, route, -1);
		SetTrieValue(hRateLeft, route, -1);
		SetTrieValue(hRateLimit, route, -1);
	}
}
