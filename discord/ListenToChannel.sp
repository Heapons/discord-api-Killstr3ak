#define SERVERS_BUSY_RETRY_TIME 10.0

int g_iTimes = 0;

public int DiscordBot_StartTimer(Handle plugin, int params)
{
	DiscordBot bot = GetNativeCell(1);
	DiscordChannel channel = GetNativeCell(2);
	OnDiscordChannelMessage cb = view_as<OnDiscordChannelMessage>(GetNativeFunction(3));

	DataPack pack = new DataPack();
	pack.WriteCell(bot);
	pack.WriteCell(plugin);
	pack.WriteFunction(cb);
	pack.WriteCell(channel);

	ListenGetMessages(bot, channel, pack);
}

static void ListenGetMessages(DiscordBot bot, DiscordChannel channel, DataPack pack)
{
	char channelid[32];
	channel.GetID(channelid, sizeof(channelid));

	char lastmessageid[32];
	channel.GetLastMessageID(lastmessageid, sizeof(lastmessageid));

	char route[256];

	Format(route, sizeof(route), "channels/%s/messages?limit=%i&after=%s", channelid, 100, lastmessageid);

	SendRequest(bot, route, _, k_EHTTPMethodGET, OnListenChannelDataReceived, _, pack);
}

public int OnListenChannelDataReceived(Handle request, bool failure, int offset, int statuscode, DataPack pack)
{
	if(failure || (statuscode != 200 && statuscode != 204))
	{
		//	bad format	 		rate limit   	server error handling		bad gateway
		if(statuscode == 400 || statuscode == 429 || statuscode == 500 || statuscode == 502)
		{
			pack.Reset();
			DiscordBot bot = pack.ReadCell();
			CreateTimer(bot.MessageCheckInterval, GetMessageTimer, pack, TIMER_FLAG_NO_MAPCHANGE);
			delete request;
			return;
		}
		//	discord server on high load
		if(statuscode == 503)
		{
			CreateTimer(SERVERS_BUSY_RETRY_TIME*g_iTimes, GetMessageTimer, pack, TIMER_FLAG_NO_MAPCHANGE);
			delete request;
			new DiscordException("Failed to ListenToChannel. Discord Servers are busy. Retrying after %.0f seconds.", SERVERS_BUSY_RETRY_TIME*g_iTimes);
			if(g_iTimes < 9)
			{
				g_iTimes++;
			}
			return;
		}
		
		new DiscordException("OnListenChannelDataReceived - Fail %i %i", failure, statuscode);
		delete pack;
		delete request;
		return;
	}

	SteamWorks_GetHTTPResponseBodyCallback(request, ReceivedData, pack);
	delete request;
}

static stock Action GetMessageTimer(Handle timer, DataPack pack)
{
	pack.Reset();
	DiscordBot bot = pack.ReadCell();
	pack.ReadCell(); // read plugin handle to jump position..
	pack.ReadFunction(); // read function callback to jump position..
	DiscordChannel channel = pack.ReadCell();

	ListenGetMessages(bot, channel, pack);
}

static int ReceivedData(const char[] data, DataPack pack)
{
	g_iTimes = 0;
	
	pack.Reset();
	DiscordBot bot = view_as<DiscordBot>(pack.ReadCell());
	Handle plugin = pack.ReadCell();
	Function callback = pack.ReadFunction();
	DiscordChannel channel = pack.ReadCell();

	if(bot == null)
	{
		delete pack;
		return;
	}
	
	if(!bot.IsListeningToChannel(channel))
	{
		if(channel != null)
		{
			channel.SetLastMessageID("");
			json_cleanup_and_delete(channel);
		}
		delete pack;
		return;
	}
	
	if(callback == INVALID_FUNCTION)
	{
		delete pack;
		return;
	}

	char channelid[32];
	DiscordMessageList messages = view_as<DiscordMessageList>(json_decode(data));

	for(int i = messages.Length - 1; i >= 0; i--)
	{
		DiscordMessage message = view_as<DiscordMessage>(messages.GetObject(i));
		message.GetChannelID(channelid, sizeof(channelid));

		if(!bot.IsListeningToChannelID(channelid))
		{
			delete pack;
			return;
		}

		if(i == 0)
		{
			char messageid[64];
			message.GetID(messageid, sizeof(messageid));
			channel.SetLastMessageID(messageid);
		}

		Call_StartFunction(plugin, callback);
		Call_PushCell(bot);
		Call_PushCell(channel);
		Call_PushCell(message);
		Call_Finish();
	}
	CreateTimer(bot.MessageCheckInterval, GetMessageTimer, pack, TIMER_FLAG_NO_MAPCHANGE);
}
