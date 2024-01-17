############################################################
#region debug
import { createLogFunctions } from "thingy-debug"
{log, olog} = createLogFunctions("navmodule")
#endregion

############################################################
import * as app from "./appcoremodule.js"
import * as S from "./statemodule.js"

############################################################
navState = {}

############################################################
rootState = {
    base: "RootState"
    modifier: "none"
    ctx: null
    # depth: history.length - 1
    depth: 0
    navLineId: null
    navAction: null
}

############################################################
pageloadAction = {
    action: "pageload"
    timestamp: Date.now()
    navLineId: null
}

refreshAction = {
    action: "refresh"
    timestamp: Date.now()
    navLineId: null
}

############################################################
NAV_info = {
    nextNavLineId: 1000
    lastNavAction: pageloadAction
}

############################################################
navLineId = null

############################################################
backNavigationPromiseResolve = null

############################################################
export initialize = ->
    log "initialize"
    window.addEventListener("popstate", historyStateChanged)
    
    info = sessionStorage.getItem("NAV_info")
    if !info? then storeNavInfo(NAV_info)
    
    NAV_info = JSON.parse(sessionStorage.getItem("NAV_info"))
    # NAV_latest_info = S.load("NAV_latest_info")
    # if !NAV_latest_info? or !NAV_latest_info.cause?
    #     S.save("NAV_latest_info", NAV_first_info, true)
    return

############################################################
export appLoaded = ->
    # log "appLoaded"
    # olog {
    #     historyState: history.state
    #     historyLength: history.length
    # }
    if !isValidHistoryState() 
        ## This is the very first appload    
        # log "-> Initial AppLoad :-)"
        navLineId = NAV_info.nextNavLineId
        pageloadAction.navLineId = navLineId
        rootState.navLineId = navLineId
        rootState.navAction = pageloadAction

        NAV_info.nextNavLineId++
        NAV_info.lastNavAction = pageloadAction
        storeNavInfo(NAV_info)
        
        history.replaceState(rootState, "")
    else
        ## we must've done some kind of refresh
        # log " -> App Refreshed!"
        navState = history.state
        navLineId = navState.navLineId
        refreshAction.navLineId = navLineId
        navState.navAction = refreshAction

        NAV_info.lastNavAction = refreshAction
        storeNavInfo(NAV_info)        
        
        history.replaceState(navState, "")

    navState = history.state
    displayState(navState)
    app.loadAppWithNavState(navState)
    return

############################################################
historyStateChanged = (evnt) ->
    log "historyStateChanged"
    olog {
        eventState: evnt.state
        historyState: history.state
        historyLength: history.length
    }
    if !isValidHistoryState() then throw new Error("No Valid History State on popstateEvent!")
    # history.replaceState(rootState, "") 
    navState = history.state
    navLineId = navState.navLineId
    # ## Analyse NAV_latest_info
    # NAV_latest_info = S.load("NAV_latest_info")
    # olog { NAV_latest_info }

    # better look into the local storage state to notice any back navigation
    # if backNavigationPromiseResolve? 
    #     ## prod log "resolving backNavigation Promise"
    #     backNavigationPromiseResolve()
    #     backNavigationPromiseResolve = null

    displayState(navState)
    app.setNavState(navState)    
    return

############################################################
#region Helper Functions

navigateTo = (base, modifier, context) ->
    log "navigateTo"
    olog {base, modifier, context}

    navState.base = base
    navState.modifier = modifier
    navState.ctx = context || null
    navState.depth = navState.depth + 1

    # NAV_latest_info = {
    #     cause: "modifier" 
    #     direction: "forward"
    #     newDepth: navState.depth
    # }
    # S.save("NAV_latest_info", NAV_latest_info, true)

    history.pushState(navState, "")
    displayState(navState)
    app.setNavState(navState)
    return


# Do we need this?
# backNavigationFinished = ->
#     return new Promise (resolve) ->
#         backNavigationPromiseResolve = resolve

############################################################
isValidHistoryState = ->
    if !history.state? then return false
    historyKeys = Object.keys(history.state)
    rootKeys = Object.keys(rootState)
    if historyKeys.length != rootKeys.length then return false

    for hKey,idx in historyKeys
        if hKey != rootKeys[idx] then return false
    return true

############################################################
displayState = (state) ->
    return unless navstatedisplay?
    stateString = JSON.stringify(state, null, 4)
    navstatedisplay.innerHTML = stateString
    return

############################################################
storeNavInfo = (info) -> sessionStorage.setItem("NAV_info", JSON.stringify(info))

#endregion

############################################################
#region Navigation Functions
export navigateModifier = (newMod, context) ->
    log "navigateModifier"
    olog { newMod, context }
    oldMod = navState.modifier

    ## case 0 - oldMod is newMod 
    if oldMod == newMod
        log "case 0 - oldMod is newMod"
        ## Nothing to be done :-)
        return

    ## case 1 - oldMod is "none" newMod is not "none"
    if oldMod == "none" and newMod != "none"
        log "case 1 - oldMod is 'none' newMod is not 'none'"
        ## regular state navigation to state with the modifier
        navigateTo(navState.base, newMod, context)
        return

    ## case 2 - oldMod is not "none" newMod is "none"
    if oldMod != "none" and newMod == "none"
        log "case 2 - oldMod is not 'none' newMod is 'none'"
        ## navigate backwards

        NAV_latest_info = {
            cause: "modifier" 
            direction: "back"
            newDepth: navState.depth - 1
        }
        S.save("NAV_latest_info", NAV_latest_info, true)

        history.back()
        # await backNavigationFinished()
        return

    ## case 3 - oldMod is not "none" newMod is different
    if oldMod != "none"
        log "case 3 - oldMod is not 'none' newMod is different"        
        ## replace state with new State
        navState.modifier = newMod
        navState.ctx = context || null

        NAV_latest_info = {
            cause: "modifier" 
            direction: "replace"
            newDepth: navState.depth
        }
        S.save("NAV_latest_info", NAV_latest_info, true)

        history.replaceState(navState, "")
        app.setNavState(navState)
        displayState(navState)

    return

export navigateBaseState = (newBase, context) ->
    log "navigateBaseState"
    olog {newBase, context}
    return



## ================== Old Functions ====================
export addStateNavigation = (newBase, context) ->
    ## prod log "addStateNavigation"
    await unmodify()

    ## Check: what to do if only Context changed?
    ## For now we ignore context as this is not a navigatable change
    if navState.base == newBase and navState.modifier == "none" then return
    state = {
        base: newBase
        modifier: "none"
        ctx: context || null
        depth: navState.depth + 1
    }
    navState = state
    history.pushState(navState, "")
    S.set("navState", navState)
    displayState(navState)
    return

export addModification = (modifier, context) ->
    ## prod log "addModification"
    ## Check: what to do if only Context changed?
    ## For now we ignore context as this is not a navigatable change
    if navState.modifier == modifier then return
    await unmodify()
    state = {
        base: navState.base
        modifier: modifier
        ctx: context || null
        depth: navState.depth + 1
    }

    navState = state
    history.pushState(navState, "")
    S.set("navState", navState)
    displayState(navState)
    return

############################################################
export backToRoot = ->
    if backNavigationPromiseResolve? then return
    ## prod log "backToRoot"
    depth = navState.depth
    return if depth == 0

    ## Back navigation sets "navState" by popstate event
    history.go(-depth)
    await backNavigationFinished()
    return

export backOne = ->
    if backNavigationPromiseResolve? then return
    ## prod log "backOne"
    depth = navState.depth
    return if depth == 0

    ## Back navigation sets "navState" by popstate event
    history.back()
    await backNavigationFinished()
    return

export unmodify = ->
    if backNavigationPromiseResolve? then return
    ## prod log "unmodify"
    return if navState.modifier == "none"

    ## Back navigation sets "navState"
    history.back()
    await backNavigationFinished()
    log "unmodification finished!"
    return

#endregion