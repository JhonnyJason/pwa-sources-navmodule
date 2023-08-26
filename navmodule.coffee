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
    base: "Root State"
    modifier: "none"
    depth: 0
}

############################################################
backNavigationPromiseResolve = null

############################################################
export initialize = ->
    log "initialize"
    window.addEventListener("popstate", historyStateChanged)
    # S.set("navState", navState) ## probably unnecessary
    return

############################################################
export appEntry = ->
    log "appEntry"
    olog {
        historyState: history.state
        historyLength: history.length
    }
    log " "
    if !history.state? then history.replaceState(rootState, "Root State") 
    navState = history.state
    S.set("navState", navState)
    displayState(navState)
    app.startUp()
    return

############################################################
historyStateChanged = (evnt) ->
    log "historyStateChanged"
    olog {
        historyState: history.state
        historyLength: history.length
    }
    log " "

    if !history.state? then history.replaceState(rootState, "Root State") 
    navState = history.state
    S.set("navState", navState)
    displayState(navState)

    if backNavigationPromiseResolve? 
        log "resolving backNavigation Promise"
        backNavigationPromiseResolve()
        backNavigationPromiseResolve = null
    return

############################################################
#region Helper Functions
backNavigationFinished = ->
    return new Promise (resolve) ->
        backNavigationPromiseResolve = resolve

############################################################
displayState = (state) ->
    log "displayState"
    stateString = JSON.stringify(state, null, 4)
    navstatedisplay.innerHTML = stateString
    return

#endregion

############################################################
#region Navigation Functions

export backToRoot = ->
    log "backToRoot"
    depth = navState.depth
    return if depth == 0

    ## Back navigation sets "navState"
    history.go(-depth)
    return

export addStateNavigation = (state) ->
    log "addStateNavigation"
    await unmodify()
    state = {
        base: state
        modifier: "none"
        depth: navState.depth + 1
    }
    navState = state
    history.pushState(navState, "")
    S.set("navState", navState)
    displayState(navState)
    return

export addModification = (modifier)->
    log "addModification"
    await unmodify()
    state = {
        base: navState.base
        modifier: modifier
        depth: navState.depth + 1
    }
    navState = state
    history.pushState(navState, "")
    S.set("navState", navState)
    displayState(navState)
    return

export unmodify = ->
    log "unmodify"
    return unless navState.modifier != "none"
    ## Back navigation sets "navState"
    history.back()
    await backNavigationFinished()
    return

#endregion