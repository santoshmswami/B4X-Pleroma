﻿B4J=true
Group=UI
ModulesStructureVersion=1
Type=Class
Version=8.3
@EndOfDesignText@
#Event: AvatarClicked (Account As PLMAccount)
#Event: LinkClicked (URL As PLMLink)
#Event: TitleChanged (Title As String)
Sub Class_Globals
	Private CLV As CustomListView
	Type StatusesListUsedManager (UsedStatusViews As Map, UnusedStatusViews As B4XSet)
	Private WaitingForItems As Boolean
	Public mBase As B4XView 'ignore
	Private xui As XUI 'ignore
	Public feed As PleromaFeed
	Private pnlLargeImage As B4XView
	Type PLMCLVItem (Content As Object, Height As Int, Empty As Boolean)
	Private ZoomImageView1 As ZoomImageView
	Private RefreshIndex As Int
	Private mEventName As String 'ignore
	Private mCallBack As Object 'ignore
	Public Stack As StackManager
	Private btnBack As B4XView
	Private AccountView1 As AccountView
	Private LastScrollPosition As Int
	Private StatusesViewsManager As StatusesListUsedManager
	Private MiniAccountsManager As StatusesListUsedManager	
	Private ViewsManagers As List
	Private TargetId As String
End Sub

Public Sub Initialize (Callback As Object, EventName As String, Root1 As B4XView)
	mEventName = EventName
	mCallBack = Callback
	mBase = Root1
	mBase.LoadLayout("StatusList")
	StatusesViewsManager = CreateStatusesListUsedManager
	MiniAccountsManager = CreateStatusesListUsedManager
	ViewsManagers = Array(StatusesViewsManager, MiniAccountsManager)
	Stack.Initialize (Me)
	feed.Initialize (Me)
	AddMoreItems
End Sub

Public Sub Resize (Width As Int, Height As Int)
	CLV.AsView.Height = Height
	CLV.Base_Resize(CLV.AsView.Width, Height)
End Sub

Public Sub Refresh
	feed.mLink.NextURL = ""
	Refresh2(feed.user, feed.mLink, False, False)
End Sub

Public Sub Refresh2 (User As PLMUser, NewLink As PLMLink, AddCurrentToStack As Boolean, GetFromStackIfAvailable As Boolean)
	If GetFromStackIfAvailable And Stack.Stack.ContainsKey(NewLink.Title) Then
		Dim item As StackItem = Stack.Stack.Get(NewLink.Title)
		Stack.Stack.Remove(NewLink.Title)
		RefreshImpl(User, Null, AddCurrentToStack, item)
	Else
		RefreshImpl(User, NewLink, AddCurrentToStack, Null)
	End If
End Sub

Private Sub RefreshImpl (User As PLMUser, NewLink As PLMLink, AddCurrentToStack As Boolean, GoToItem As StackItem)
	btnBack.Visible = False
	If AddCurrentToStack Then
		If GoToItem = Null Or GoToItem.Link.Title <> feed.mLink.Title Then
			Stack.Push(feed, CLV)
		End If
	End If
	Wait For (StopAndClear) Complete (unused As Boolean)
	TargetId = ""
	If GoToItem <> Null Then
		NewLink = GoToItem.Link
		feed.user = GoToItem.User
		feed.server = GoToItem.Server
		feed.mLink = GoToItem.Link
		feed.Statuses = GoToItem.Statuses
		CreateItemsFromStack(GoToItem.CLVItems, GoToItem.CurrentScrollOffset)
	Else
		feed.user = User
		feed.mLink = NewLink
		If NewLink.Extra.IsInitialized And NewLink.Extra.ContainsKey("targetId") Then
			TargetId = NewLink.Extra.Get("targetId")
			B4XPages.MainPage.ShowProgress
		End If
	End If
	feed.Start (GoToItem <> Null)
	CallSub2(mCallBack, mEventName & "_TitleChanged", NewLink.Title)
	If CLV.Size = 0 Then
		AddMoreItems
	End If
	UpdateBackKey
End Sub

Public Sub UpdateBackKey
	btnBack.Visible = Stack.IsEmpty = False
End Sub

Public Sub StopAndClear As ResumableSub
	RefreshIndex = RefreshIndex + 1
	Dim MyIndex As Int = RefreshIndex
	Do While WaitingForItems
		Sleep(50)
		If RefreshIndex <> MyIndex Then Return False
	Loop
	feed.Stop
	RemoveInvisibleItems(0, 0, True)
	CLV.Clear
	CLV.sv.ScrollViewOffsetY = 0
	CloseLargeImage
	Return True
End Sub


Private Sub GoBack
	Dim items As B4XOrderedMap = Stack.Stack
	Dim LastItem As StackItem = items.Get(items.Keys.Get(items.Keys.Size - 1))
	Stack.Stack.Remove(LastItem.Link.Title)
	RefreshImpl(Null, Null, False, LastItem)
End Sub

Public Sub CreateItemsFromStack(Items As List, Offset As Int)
	For Each ci As PLMCLVItem In Items
		Dim pnl As B4XView = xui.CreatePanel("")
		pnl.SetLayoutAnimated(0, 0, 0, CLV.AsView.Width, ci.Height)
		AddItemToCLVAndRemoveTouchEvent(pnl, ci)
	Next
	Sleep(20)
	CLV.sv.ScrollViewOffsetY = Offset
	Sleep(0)
	CLV_VisibleRangeChanged(CLV.FirstVisibleIndex, CLV.LastVisibleIndex)
End Sub

Public Sub GetCurrentIndex As Int
	Return CLV.LastVisibleIndex
End Sub

Public Sub TickAndIsWaitingForItems As Boolean
	If TargetId <> "" Then
		Return True
	End If
	#if RELEASE
	If LastScrollPosition = Floor(CLV.sv.ScrollViewOffsetY) Then
		If WaitingForItems = False And CLV.LastVisibleIndex + 30 > CLV.Size Then
			AddMoreItems
		End If
	End If
	#end if
	LastScrollPosition = CLV.sv.ScrollViewOffsetY
	Return WaitingForItems Or feed.Statuses.Size < CLV.Size + 30
End Sub

Private Sub JumpToTarget
	Log("jump to target")
	Sleep(0)
	B4XPages.MainPage.HideProgress
	Dim i As Int = feed.Statuses.Keys.IndexOf(TargetId)
	CLV.JumpToItem(i)
	TargetId = ""
End Sub

Private Sub AreThereMoreItems As Boolean
	If CLV.Size = 0 Then Return True
	Dim last As PLMCLVItem = CLV.GetValue(CLV.Size - 1)
	Return last.Content <> feed.NoMoreItems
End Sub

Private Sub AddMoreItems
	If WaitingForItems Then Return
	If AreThereMoreItems = False Then Return
	WaitingForItems = True
	Dim MyRefreshIndex As Int = RefreshIndex
	Dim ProgressBar As Boolean
	If CLV.LastVisibleIndex = CLV.Size - 1 Then
		ProgressBar = True
		B4XPages.MainPage.ShowProgress
	End If
	Do Until feed.Statuses.Size > CLV.Size
		Sleep(100)
		If MyRefreshIndex <> RefreshIndex Then
			WaitingForItems = False
			If ProgressBar Then B4XPages.MainPage.HideProgress
			Return
		End If
	Loop
	Dim NewList As Boolean = CLV.Size = 0 And TargetId = ""
	Dim MaxIndex As Int = Min(feed.Statuses.Size - 1, CLV.Size + 10)
	If TargetId <> "" Then MaxIndex = feed.Statuses.Size - 1
	For i = CLV.Size To MaxIndex
		Dim Content As Object = feed.Statuses.Get(feed.Statuses.Keys.Get(i))
		Dim pnl As B4XView = xui.CreatePanel("")
		pnl.SetLayoutAnimated(0, 0, 0, CLV.AsView.Width, 20dip)
		Dim ContentView As Object = GetContentView(i, Content)
		CallSub2(ContentView, "SetContent", Content)
		Dim ContentBase As B4XView = CallSub(ContentView, "GetBase")
		pnl.AddView(ContentBase , 0, 0, ContentBase.Width, ContentBase.Height)
		pnl.Height = ContentBase.Height
		Dim Value As PLMCLVItem = CreatePLMCLVItem(Content)
		Value.Empty = False
		Value.Height = pnl.Height
		AddItemToCLVAndRemoveTouchEvent(pnl, Value)
		CallSub2(ContentView, "SetVisibility", IsVisible(i, CLV.FirstVisibleIndex, CLV.LastVisibleIndex))
		If i = 5 And NewList Then Exit
	Next
	CLV_ScrollChanged(CLV.sv.ScrollViewOffsetY)
	If ProgressBar Then B4XPages.MainPage.HideProgress
	WaitingForItems = False
	If TargetId <> "" And feed.Statuses.ContainsKey(TargetId) Then
		JumpToTarget
	End If
End Sub

Private Sub AddItemToCLVAndRemoveTouchEvent(pnl As B4XView, value As PLMCLVItem)
	CLV.Add(pnl, value)
	#if B4i
	RemoveClickRecognizer(pnl)
	#End If
End Sub

#if B4i
Public Sub RemoveClickRecognizer (pnl As B4XView)
	Dim no As NativeObject = pnl.Parent
	Dim recs As List = no.GetField("gestureRecognizers")
	For Each rec As Object In recs
		no.RunMethod("removeGestureRecognizer:", Array(rec))
	Next
End Sub
#End If

Private Sub AddContentView (Index As Int)
	Dim value As PLMCLVItem = CLV.GetValue(Index)
	Dim ContentView As Object = GetContentView(Index, value.Content)
	Dim parent As B4XView = CLV.GetPanel(Index)
	parent.AddView(CallSub(ContentView, "GetBase"), 0, 0, parent.Width, parent.Height)
	CallSub2(ContentView, "SetVisibility", IsVisible(Index, CLV.FirstVisibleIndex, CLV.LastVisibleIndex))
	CallSub2(ContentView, "SetContent", value.Content)
	value.Empty = False
	If ContentView Is StatusView Then
		Dim sv As StatusView = ContentView
		sv.ParentScrolled(CLV.sv.ScrollViewOffsetY, CLV.sv.Height)
	End If
End Sub

Private Sub RemoveView (manager As StatusesListUsedManager, sv As Object)
	Dim value As PLMCLVItem = CLV.GetValue(manager.UsedStatusViews.Get(sv))
	value.Empty = True
	CallSub(sv, "RemoveFromParent")
	manager.UsedStatusViews.Remove(sv)
	manager.UnusedStatusViews.Add(sv)
End Sub

Private Sub RemoveInvisibleItems (FirstIndex As Int, LastIndex As Int, All As Boolean)
	For Each manager As StatusesListUsedManager In ViewsManagers
		Dim ItemsToRemove As List
		For Each sv As Object In manager.UsedStatusViews.Keys
			Dim ListIndex As Int = manager.UsedStatusViews.Get(sv)
			If All Or IsVisible(ListIndex, FirstIndex, LastIndex + 10) = False Then
				If ItemsToRemove.IsInitialized = False Then ItemsToRemove.Initialize
				ItemsToRemove.Add(sv)
			Else
				CallSub2(sv, "SetVisibility", IsVisible(ListIndex, FirstIndex, LastIndex))
			End If
		Next

		If ItemsToRemove.IsInitialized Then
			For Each sv As Object In ItemsToRemove
				RemoveView(manager, sv)
			Next
		End If
	Next
	If AccountView1.IsInitialized And AccountView1.mBase.Parent.IsInitialized Then
		If All Or IsVisible(0, FirstIndex, LastIndex) = False Then
			AccountView1.RemoveFromParent
			Dim value As PLMCLVItem = CLV.GetValue(0)
			value.Empty = True
		End If
	End If
	If All And AreThereMoreItems = False Then
		Dim value As PLMCLVItem = CLV.GetValue(CLV.Size - 1)
		value.Empty = True
	End If
	If All Then
		
	End If
End Sub

Sub CLV_VisibleRangeChanged (FirstIndex As Int, LastIndex As Int)
	If LastIndex >= CLV.Size Then Return
	FirstIndex = Max(0, FirstIndex - 2)
	LastIndex = Min(CLV.Size - 1, LastIndex + 2)
	RemoveInvisibleItems(FirstIndex, LastIndex, False)
	For i = FirstIndex To LastIndex
		Dim value As PLMCLVItem = CLV.GetValue(i)
		If value.Empty Then
			AddContentView(i)
		End If
	Next
	If LastIndex > = CLV.Size - 5 Then
		AddMoreItems
	End If
End Sub

Private Sub CLV_ScrollChanged (ScrollViewOffset As Int)
	For Each sv As StatusView In StatusesViewsManager.UsedStatusViews.Keys
		sv.ParentScrolled(ScrollViewOffset, CLV.sv.Height)
	Next
End Sub

Private Sub GetContentView (ListIndex As Int, Content As Object) As Object
	If Content Is PLMStatus Then
		Return GetStatusView(ListIndex)
	Else if Content Is PLMAccount Then
		If AccountView1.IsInitialized = False Then
			Dim p As B4XView = xui.CreatePanel("")
			p.SetLayoutAnimated (0, 0, 0, CLV.AsView.Width, 104dip)
			AccountView1.Initialize(p, Me, "StatusView1")
		End If
		Return AccountView1
	Else If Content Is PLMMiniAccount Then
		Dim mini As MiniAccountView = GetViewFromManager(MiniAccountsManager)
		If mini = Null Then
			Dim mini As MiniAccountView
			Dim p As B4XView = xui.CreatePanel("")
			p.SetLayoutAnimated (0, 0, 0, CLV.AsView.Width, 70dip)
			mini.Initialize(p, Me, "StatusView1")
		End If
		MiniAccountsManager.UsedStatusViews.Put(mini, ListIndex)
		mini.ListIndex = ListIndex
		Return mini
	Else
		Dim stub As StubView
		stub.Initialize(CLV.AsView.Width)
		Return stub
	End If
End Sub

Private Sub GetStatusView (ListIndex As Int) As StatusView
	Dim sv As StatusView = GetViewFromManager(StatusesViewsManager)
	If sv = Null Then
		Dim sv As StatusView
		Dim pnl As B4XView = xui.CreatePanel("")
		pnl.SetLayoutAnimated(0, 0, 0, CLV.AsView.Width, 300dip)
		sv.Initialize(Me, "StatusView1")
		sv.Create(pnl)
		sv.mBase.RemoveViewFromParent
	End If
	sv.ListIndex = ListIndex
	StatusesViewsManager.UsedStatusViews.Put(sv, ListIndex)
	Return sv
End Sub

Private Sub GetViewFromManager (Manager As StatusesListUsedManager) As Object
	If Manager.UnusedStatusViews.Size > 0 Then
		Dim o As Object = Manager.UnusedStatusViews.AsList.Get(0)
		Manager.UnusedStatusViews.Remove(o)
		Return o
	End If
	Return Null
End Sub


Private Sub IsVisible(Index As Int, FirstIndex As Int, LastIndex As Int) As Boolean
	Return Index >= FirstIndex And Index <= LastIndex
End Sub

Sub CLV_ItemClick (Index As Int, Value As Object)
	Dim St As PLMCLVItem = Value
	If St.Content Is PLMStatus Then
		Dim s As PLMStatus = St.Content
		Log(s.id)
	End If
End Sub

Private Sub StatusView1_ShowLargeImage (URL As String)
	B4XPages.MainPage.Drawer.GestureEnabled = False
	If ZoomImageView1.Tag Is ImageConsumer Then
		B4XPages.MainPage.ImagesCache1.ReleaseImage(ZoomImageView1.Tag)
	End If
	Dim Consumer As ImageConsumer
	Consumer.Initialize
	Consumer.CBitmaps.Initialize
	Consumer.Target = ZoomImageView1.mBase
	Consumer.IsVisible = True
	ZoomImageView1.Tag = Consumer
	Dim ic As ImagesCache = B4XPages.MainPage.ImagesCache1
	If ic.IsImageReady(URL) = False Then
		ic.SetPermImageImmediately(ic.EMPTY, ZoomImageView1.Tag, ic.RESIZE_NONE)
		Consumer.NoAnimation = True		
	End If
	ic.SetImage(URL, ZoomImageView1.Tag, ic.RESIZE_NONE)
End Sub

Private Sub StatusView1_AvatarClicked (Account As PLMAccount)
	CallSub2(mCallBack, mEventName & "_AvatarClicked", Account)
End Sub

Private Sub StatusView1_LinkClicked (URL As PLMLink)
	CallSub2(mCallBack, mEventName & "_LinkClicked", URL)
End Sub

Private Sub CreatePLMCLVItem (Content As Object) As PLMCLVItem
	Dim t1 As PLMCLVItem
	t1.Initialize
	t1.Content = Content
	t1.Empty = True
	Return t1
End Sub

Private Sub CloseLargeImage
	If pnlLargeImage.Visible Then
		B4XPages.MainPage.Drawer.GestureEnabled = True
		pnlLargeImage.SetVisibleAnimated(100, False)
	End If
End Sub

Public Sub BackKeyPressedShouldClose As Boolean
	If pnlLargeImage.Visible Then
		CloseLargeImage
		Return False
	End If
	If btnBack.Visible Then
		GoBack
		Return False
	End If
	Return True
End Sub

Sub ZoomImageView1_Click
	CloseLargeImage
End Sub

Private Sub btnBack_Click
	GoBack
	XUIViewsUtils.PerformHapticFeedback(mBase)
End Sub

Private Sub CreateStatusesListUsedManager As StatusesListUsedManager
	Dim t1 As StatusesListUsedManager
	t1.Initialize
	t1.UsedStatusViews.Initialize
	t1.UnusedStatusViews.Initialize
	Return t1
End Sub