public int OnDiscordDataReceived(Handle request, bool failure, int offset, int statuscode, DataPack pack)
{
	if(failure || (statuscode != 200 && statuscode != 204))
	{
		if(statuscode == 400 || statuscode == 429 || statuscode == 500)
		{
			// bad format or rate limit or server error handling
		}
		
		new DiscordException("OnDiscordDataReceived - Fail %i %i", failure, statuscode);
		delete request;
		return;
	}

	SteamWorks_GetHTTPResponseBodyCallback(request, ReceivedData, pack);
	delete request;
}

static int ReceivedData(const char[] data, DataPack pack)
{
	pack.Reset();
	Handle plugin = pack.ReadCell();
	Function callback = pack.ReadFunction();
	delete pack;
	
	Call_StartFunction(plugin, callback);
	Call_PushCell(json_decode(data));
	Call_Finish();
}