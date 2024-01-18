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
        # eventState: evnt.state ## is the same as history.state
        historyState: history.state
        historyLength: history.length
    }
    if !isValidHistoryState() then throw new Error("No Valid History State on popstateEvent!") ## What to do with this? treat it as pageLoad event?
    
    navState = history.state
    navLineId = navState.navLineId

    navState.navAction = NAV_info.lastNavAction
    
    history.replaceState(navState, "")
    displayState(navState)
    # check nav Action to notice back navigation
    if navState.navAction.action == "back" and backNavigationPromiseResolve?
        ## prod log "resolving backNavigation Promise"
        backNavigationPromiseResolve()
        backNavigationPromiseResolve = null
    app.loadAppWithNavState(navState)
    return

############################################################
#region Helper Functions

navigateTo = (base, modifier, context) ->
    log "navigateTo"
    olog {base, modifier, context}

    navAction = {
        action: "nav"
        timestamp: Date.now()
        navLineId: navLineId
    }

    navState.base = base
    navState.modifier = modifier
    navState.ctx = context || null
    navState.depth = navState.depth + 1
    navState.navLineId = navLineId
    navState.navAction = navAction

    NAV_info.lastNavAction = navAction
    storeNavInfo(NAV_info)        

    history.pushState(navState, "")
    displayState(navState)
    app.setNavState(navState)
    return

navigateBack = (depth) ->
    if backNavigationPromiseResolve? then return

    navAction = {
        action: "back"
        timestamp: Date.now()
        navLineId: navLineId
    }

    NAV_info.lastNavAction = navAction
    storeNavInfo(NAV_info)        

    ## Back navigation sets "navState" by popstate event
    history.go(-depth)

    return await backNavigationFinished()
############################################################
navReplace = (base, modifier, context) ->
    log "navReplace"
    olog { base, modifier, context }
    navAction = {
        action: "nav"
        timestamp: Date.now()
        navLineId: navLineId
    }

    navState.base = base
    navState.modifier = modifier
    navState.ctx = context || null
    navState.navLineId = navLineId
    navState.navAction = navAction

    NAV_info.lastNavAction = navAction
    storeNavInfo(NAV_info)       

    history.replaceState(navState, "")
    displayState(navState)
    app.setNavState(navState)

    return

############################################################
# Do we need this?
backNavigationFinished = ->
    return new Promise (resolve) ->
        backNavigationPromiseResolve = resolve

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
        return await backOne()
        # backOne()
        # return

    ## case 3 - oldMod is not "none" newMod is different
    if oldMod != "none"
        log "case 3 - oldMod is not 'none' newMod is different"        
        ## replace state with new State
        navReplace(navState.base, newMod, context)
        return
    
    return

export navigateBaseState = (newBase, context) ->
    log "navigateBaseState"
    olog {newBase, context}
    oldMod = navState.modifier

    if oldMod == "none" then return navigateTo(newBase, oldMod, context)

    ## If we have some modifier on, then we need to replace the current state
    navReplace(newBase, "none", context)
    return


############################################################
export backToRoot = ->
    ## prod log "backToRoot"
    depth = navState.depth
    return if depth == 0
    return navigateBack(depth)

export backOne = ->
    ## prod log "backOne"
    depth = navState.depth
    return if depth == 0    
    return navigateBack(1)

export back = backOne

export unmodify = -> await navigateModifier("none")

#endregion