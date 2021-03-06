﻿B4J=true
Group=Network
ModulesStructureVersion=1
Type=Class
Version=8.3
@EndOfDesignText@
Sub Class_Globals
	Type PLMContent (RootHtmlNode As HtmlNode)
	Type PLMAccount (Avatar As String, Id As String, Url As String, UserName As String, DisplayName As String, Acct As String, _
		Note As String, FollowersCount As Int, FollowingCount As Int, StatusesCount As Int, HeaderURL As String, Emojis As List, _
		FollowedBy As Boolean, Following As Boolean, RelationshipAdded As Boolean, FollowRequested As Boolean)
	Type PLMTag (Name As String, Url As String)
	Type PLMStatus (Account As PLMAccount, Content As PLMContent, _
		id As String, CreatedAt As Long, Tags As List, URI As String, Url As String, Visibility As String, Attachments As List, _
		Sensitive As Boolean, InReplyToAccountAcct As String, RepliesCount As Int, ReblogsCount As Int, FavouritesCount As Int, _
		Mentions As List, Emojis As List, InReplyToAccountId As String, InReplyToId As String, ExtraContent As Map, _
		EmojiReactions As List, Favourited As Boolean, Reblogged As Boolean)
	Type PLMMedia (Id As String, TType As String, Url As String, PreviewUrl As String)
	Type PLMLink (URL As String, LINKTYPE As Int, Title As String, FirstURL As String, Extra As Map, NextURL As String)
	Type PLMEmoji (Shortcode As String, URL As String, Size As Int)
	Type PLMMiniAccount (Account As PLMAccount)
	Public Statuses As B4XOrderedMap
	Private Timer1 As Timer
	Private mCallback As Object
	Private DownloadingTimeLines As Boolean	
	Private DownloadIndex As Int
	Public mLink As PLMLink
	Public user As PLMUser
	Public server As PLMServer
	Public mTitle As String
	Public NoMoreItems As Object
	Private tu As TextUtils
End Sub

Public Sub Initialize (Callback As Object)
	mCallback = Callback
	Statuses.Initialize
	DateTime.DateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
	Timer1.Initialize("Timer1", 100)
	tu = B4XPages.MainPage.TextUtils1
End Sub

Public Sub Start (KeepStatuses As Boolean)
	Timer1.Enabled = True
	DownloadIndex = DownloadIndex + 1
	server = B4XPages.MainPage.Servers.Get(user.ServerName)
	If KeepStatuses = False Then
		Dim Statuses As B4XOrderedMap
		Statuses.Initialize
	End If
	DownloadingTimeLines = False
End Sub

Public Sub Stop
	Timer1.Enabled = False
	DownloadIndex = DownloadIndex + 1
End Sub

Private Sub Timer1_Tick
	If CallSub(mCallback, "TickAndIsWaitingForItems") = True Then
		Dim LastStatus As Object
		If Statuses.Size > 0 Then LastStatus = Statuses.Get(Statuses.Keys.Get(Statuses.Size - 1))
		If LastStatus = NoMoreItems Then Return
		Dim settings As Map = CreateMap("limit": 10, "only_media": False)
		If mLink.NextURL <> "" Then
			'
		Else if LastStatus Is PLMStatus Then
			Dim sm As PLMStatus = LastStatus
			settings.Put("max_id", sm.id)
		Else
			settings.Put("limit", 5)
'			settings.Put("max_id", "9yXOFMjCv39XhF6fgG")
		End If
		If mLink.LINKTYPE = B4XPages.MainPage.LINKTYPE_SEARCH Then
			
			settings.Put("q", mLink.Extra.Get("query"))
			settings.Put("limit", 20)
		End If
		Download(settings)
	End If
End Sub

Private Sub Download (Params As Map)
	If DownloadingTimeLines Then Return
	DownloadingTimeLines = True
	Dim MyIndex As Int = DownloadIndex
	Dim j As HttpJob
	j.Initialize("", Me)
	Dim IsFirst As Boolean
	Dim url As String
	If Statuses.Size = 0 And mLink.FirstURL <> "" Then
		IsFirst = True
		url = server.URL & mLink.FirstURL
	Else If mLink.NextURL <> "" Then
		url = mLink.NextURL
		Params.Clear
	Else
		url = server.URL & mLink.URL
	End If
	j.Download2(url, MapToArray(Params))
	B4XPages.MainPage.auth.AddAuthorization(j)
	Wait For (j) JobDone (j As HttpJob)
	If MyIndex <> DownloadIndex Then
		j.Release
		Return
	End If
	If j.Success Then
		Dim res As B4XOrderedMap
		Dim CurrentSize As Int = Statuses.Size
		Dim str As String = j.GetString
		Select mLink.LINKTYPE
			Case B4XPages.MainPage.LINKTYPE_SEARCH
				Wait For (ParseSearch(str)) Complete (res2 As B4XOrderedMap)
				res = res2
			Case B4XPages.MainPage.LINKTYPE_THREAD
				res = ParseThread(str)
			Case B4XPages.MainPage.LINKTYPE_TAG, B4XPages.MainPage.LINKTYPE_TIMELINE
				res = ParseTimelines(str)
			Case B4XPages.MainPage.LINKTYPE_USER
				Dim IsStatuses As Boolean = mLink.URL.EndsWith("statuses")
				If IsFirst Then
					Dim acct As PLMAccount = ParseAccount (str)
					If IsStatuses = False Then acct.Note = ""
				Else If IsStatuses Then
					res = ParseTimelines(j.GetString)
				Else 
					SetNextLink(j)
					Wait For (ParseFollowersOrFollowing(tu.JsonParseList(str))) Complete (res2 As B4XOrderedMap)
					res = res2
					If MyIndex <> DownloadIndex Then
						j.Release
						Return
					End If
				End If
		End Select
		If res.IsInitialized Then
			For Each id As String In res.Keys
				Statuses.Put(id, res.Get(id))
			Next
		End If
		If Statuses.Size = CurrentSize Then
			Statuses.Put("last", NoMoreItems)
		End If
	End If
	If MyIndex = DownloadIndex Then
		DownloadingTimeLines = False
	End If
	j.Release
End Sub

Private Sub SetNextLink (job As HttpJob)
	Dim h As Map = job.Response.GetHeaders
	If h.ContainsKey("link") Then
		#if B4J or B4A
		Dim items As List = h.Get("link")
		Dim raw As String = items.Get(0)
		#else if B4i
		Dim raw As String = h.Get("link")
		#end if
		Log(raw)
		Dim m As Matcher = Regex.Matcher("<([^>]+)>;\s*rel=\""next\""", raw)
		If m.Find Then
			mLink.NextURL = m.Group(1)
		End If
	End If
End Sub

Private Sub MapToArray(m As Map) As String()
	Dim s(m.Size * 2) As String
	Dim counter As Int
	For Each key As String In m.Keys
		s(counter) = key
		s(counter + 1) = m.Get(key)
		counter = counter + 2
	Next
	Return s
End Sub

Private Sub ParseAccount (s As String) As PLMAccount
	Dim account As PLMAccount = tu.CreateAccount(tu.JsonParseMap(s))
	Statuses.Put(account.Id, account)
	Return account
End Sub

Private Sub ParseSearch (s As String) As ResumableSub
	Dim res As B4XOrderedMap = B4XCollections.CreateOrderedMap
	Dim m As Map = tu.JsonParseMap(s)
	
	If m.IsInitialized Then
		Dim accounts As List = m.Get("accounts")
		If accounts.Size > 0 Then
			Wait For (ParseFollowersOrFollowing(accounts)) Complete (AccountsRes As B4XOrderedMap)
		End If
		Dim stats As B4XOrderedMap = B4XCollections.CreateOrderedMap
		FillStatuses(stats, m.Get("statuses"))
		If AccountsRes = Null Or AccountsRes.IsInitialized = False Then
			res = stats
		Else
			Dim arr() As Object = Array(AccountsRes, stats)
			For i = 0 To Max(AccountsRes.Size - 1, stats.Size - 1) Step 5
				For Each map As B4XOrderedMap In arr
					For x = i To Min(i + 4, map.Size - 1)
						Dim key As String = map.Keys.Get(x)
						res.Put(key, map.get(key))
					Next
				Next
			Next
		End If
	End If
	res.Put("last", NoMoreItems)
	Return res
End Sub

Private Sub ParseThread (s As String) As B4XOrderedMap
	Dim res As B4XOrderedMap = B4XCollections.CreateOrderedMap
	Dim m As Map = tu.JsonParseMap(s)
	If m.IsInitialized = False Then Return res
	FillStatuses(res, m.Get("ancestors"))
	Dim status As PLMStatus = mLink.Extra.Get("current")
	res.Put(status.id, status)
	FillStatuses(res, m.Get("descendants"))
	Return res
End Sub

Private Sub ParseTimelines(s As String) As B4XOrderedMap
	Dim res As B4XOrderedMap = B4XCollections.CreateOrderedMap
	FillStatuses (res, tu.JsonParseList(s))
	Return res
End Sub

Private Sub FillStatuses (res As B4XOrderedMap, RawItems As List)
	If RawItems.IsInitialized = False Then Return
	For Each StatusMap As Map In RawItems
		Dim status As PLMStatus = tu.ParseStatus(StatusMap)
		res.Put(status.id, status)
	Next
End Sub

Private Sub ParseFollowersOrFollowing (accounts As List) As ResumableSub
	Dim res As B4XOrderedMap = B4XCollections.CreateOrderedMap
	If accounts.IsInitialized = False Then Return res
	Dim ParsedAccounts As Map
	ParsedAccounts.Initialize
	For Each m As Map In accounts
		Dim account As PLMAccount = tu.CreateAccount(m)
		Dim mp As PLMMiniAccount
		mp.Initialize
		mp.Account = account
		res.Put(account.Id, mp)
		ParsedAccounts.Put(account.Id, account)
	Next
	If ParsedAccounts.Size > 0 Then
		Wait For (tu.AddRelationship(ParsedAccounts)) Complete (Success As Boolean)
	End If
	Return res
End Sub





