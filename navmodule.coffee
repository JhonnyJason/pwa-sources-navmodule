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
    depth: 0
}

############################################################
backNavigationPromiseResolve = null

############################################################
export initialize = ->
    ## prod log "initialize"
    window.addEventListener("popstate", historyStateChanged)
    # S.set("navState", navState) ## probably unnecessary
    return

############################################################
export appLoaded = ->
    ## prod log "appLoaded"
    # olog {
    #     historyState: history.state
    #     historyLength: history.length
    # }
    if !isValidHistoryState() then history.replaceState(rootState, "") 
    navState = history.state
    S.set("navState", navState)
    displayState(navState)
    return

############################################################
historyStateChanged = (evnt) ->
    ## prod log "historyStateChanged"
    # olog {
    #     historyState: history.state
    #     historyLength: history.length
    # }

    if !isValidHistoryState() then history.replaceState(rootState, "") 
    navState = history.state
    S.set("navState", navState)
    displayState(navState)

    if backNavigationPromiseResolve? 
        ## prod log "resolving backNavigation Promise"
        backNavigationPromiseResolve()
        backNavigationPromiseResolve = null
    return

############################################################
#region Helper Functions
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

#endregion

############################################################
#region Navigation Functions

export backToRoot = ->
    ## prod log "backToRoot"
    depth = navState.depth
    return if depth == 0

    ## Back navigation sets "navState"
    history.go(-depth)
    return

export addStateNavigation = (newBase) ->
    ## prod log "addStateNavigation"
    await unmodify()
    if navState.base == newBase and navState.modifier == "none" then return
    state = {
        base: newBase
        modifier: "none"
        depth: navState.depth + 1
    }
    navState = state
    history.pushState(navState, "")
    S.set("navState", navState)
    displayState(navState)
    return

export addModification = (modifier)->
    ## prod log "addModification"
    if navState.modifier == modifier then return
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
    ## prod log "unmodify"
    return if navState.modifier == "none"

    ## Back navigation sets "navState"
    history.back()
    await backNavigationFinished()
    return

#endregion