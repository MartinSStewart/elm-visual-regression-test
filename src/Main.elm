module Main exposing (main, run)

import Base64
import Browser
import Bytes exposing (Bytes)
import Codec exposing (Codec)
import Html exposing (text)
import Http
import Json.Decode
import Json.Encode
import List.Nonempty exposing (Nonempty(..))
import Process
import SHA256
import Task exposing (Task)
import Url exposing (Url)
import Url.Builder


key =
    PercyApiKey "e7a6d7bcf5278626e7fb4af397b65ab994daed19df807c9917d1149b7543863d"


type Msg
    = PercyResponse (Result Http.Error FinalizeResponse)


main : Program () {} Msg
main =
    Browser.element
        { init =
            \_ ->
                ( {}
                , run ""
                    |> Task.attempt PercyResponse
                )
        , update =
            \msg _ ->
                let
                    _ =
                        Debug.log "result" msg
                in
                ( {}, Cmd.none )
        , view = \_ -> Html.text "test"
        , subscriptions = \_ -> Sub.none
        }


run : String -> Task Http.Error FinalizeResponse
run html =
    build
        key
        { attributes =
            { branch = "main"
            , targetBranch = "main"
            }
        , relationships = { resources = { data = [] } }
        }
        |> Task.andThen
            (\{ data } ->
                let
                    digest =
                        SHA256.fromString html
                in
                createSnapshot
                    key
                    data.id
                    { name = "test"
                    , widths = Nonempty 500 []
                    , minHeight = Nothing
                    , resources =
                        Nonempty
                            { id = digest
                            , attributes =
                                { resourceUrl = "/index.html"
                                , isRoot = True
                                , mimeType = "text/html"
                                }
                            }
                            []
                    }
                    |> Task.andThen (\_ -> uploadResource key data.id html)
                    |> Task.andThen (\_ -> finalize key data.id)
            )


type alias SnapshotResource =
    { id : SHA256.Digest
    , attributes :
        { resourceUrl : String
        , isRoot : Bool
        , mimeType : String
        }
    }


percyApiDomain : String
percyApiDomain =
    "https://percy.io/api/v1"


uploadResource : PercyApiKey -> BuildId -> String -> Task Http.Error ()
uploadResource (PercyApiKey apiKey) (BuildId buildId) content =
    Http.task
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Token " ++ apiKey) ]
        , url = Url.Builder.crossOrigin percyApiDomain [ "builds", buildId, "resources" ] []
        , body = Http.jsonBody (encodeUploadResource content)
        , resolver = Http.stringResolver (resolver (Codec.succeed ()))
        , timeout = Nothing
        }


encodeUploadResource : String -> Json.Encode.Value
encodeUploadResource content =
    Json.Encode.object
        [ ( "data"
          , Json.Encode.object
                [ ( "type", Json.Encode.string "resources" )
                , ( "id", SHA256.fromString content |> SHA256.toHex |> Json.Encode.string )
                , ( "attributes"
                  , Json.Encode.object
                        [ ( "base64-content"
                          , Base64.fromString content |> Maybe.withDefault "" |> Json.Encode.string
                          )
                        ]
                  )
                ]
          )
        ]


createSnapshot :
    PercyApiKey
    -> BuildId
    ->
        { name : String
        , widths : Nonempty Int
        , minHeight : Maybe Int
        , resources : Nonempty SnapshotResource
        }
    -> Task Http.Error ()
createSnapshot (PercyApiKey apiKey) (BuildId buildId) data =
    Http.task
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Token " ++ apiKey) ]
        , url = Url.Builder.crossOrigin percyApiDomain [ "builds", buildId, "snapshots" ] []
        , body = Http.jsonBody (encodeCreateSnapshot data)
        , resolver = Http.stringResolver (resolver (Codec.succeed ()))
        , timeout = Nothing
        }


encodeCreateSnapshot :
    { name : String
    , widths : Nonempty Int
    , minHeight : Maybe Int
    , resources : Nonempty SnapshotResource
    }
    -> Json.Encode.Value
encodeCreateSnapshot data =
    Json.Encode.object
        [ ( "data"
          , Json.Encode.object
                [ ( "type", Json.Encode.string "snapshots" )
                , ( "attributes"
                  , Json.Encode.object
                        [ ( "name", Json.Encode.string data.name )
                        , ( "widths", Json.Encode.null )
                        , ( "minimum-height"
                          , case data.minHeight of
                                Just minHeight ->
                                    Json.Encode.int minHeight

                                Nothing ->
                                    Json.Encode.null
                          )
                        ]
                  )
                , ( "relationships"
                  , Json.Encode.object
                        [ ( "resources"
                          , Json.Encode.object
                                [ ( "data"
                                  , Json.Encode.list encodeResource (List.Nonempty.toList data.resources)
                                  )
                                ]
                          )
                        ]
                  )
                ]
          )
        ]


type PercyApiKey
    = PercyApiKey String


type CommitSha
    = CommitSha String


type alias BuildData =
    { attributes :
        { branch : String
        , targetBranch : String
        }
    , relationships :
        { resources :
            { data : List SnapshotResource }
        }
    }


type BuildId
    = BuildId String


type alias BuildResponse =
    { data : { id : BuildId }
    }


buildResponseCodec : Codec BuildResponse
buildResponseCodec =
    Codec.object BuildResponse
        |> Codec.field
            "data"
            .data
            (Codec.object (\id -> { id = id })
                |> Codec.field "id" .id buildIdCodec
                |> Codec.buildObject
            )
        |> Codec.buildObject


buildIdCodec : Codec BuildId
buildIdCodec =
    Codec.string |> Codec.map BuildId (\(BuildId a) -> a)


encodeBuildData : BuildData -> Json.Encode.Value
encodeBuildData buildData =
    Json.Encode.object
        [ ( "data"
          , Json.Encode.object
                [ ( "type", Json.Encode.string "builds" )
                , ( "attributes"
                  , Json.Encode.object
                        [ ( "branch", Json.Encode.string buildData.attributes.branch )
                        , ( "target-branch", Json.Encode.string buildData.attributes.targetBranch )
                        ]
                  )
                , ( "relationships"
                  , Json.Encode.object
                        [ ( "resources"
                          , Json.Encode.object
                                [ ( "data"
                                  , Json.Encode.list encodeResource buildData.relationships.resources.data
                                  )
                                ]
                          )
                        ]
                  )
                ]
          )
        ]


encodeResource : SnapshotResource -> Json.Encode.Value
encodeResource resource =
    Json.Encode.object
        [ ( "type", Json.Encode.string "resources" )
        , ( "id", SHA256.toHex resource.id |> Json.Encode.string )
        , ( "attributes"
          , Json.Encode.object
                [ ( "resource-url", Json.Encode.string resource.attributes.resourceUrl )
                , ( "is-root", Json.Encode.bool resource.attributes.isRoot )
                , ( "mimetype", Json.Encode.string resource.attributes.mimeType )
                ]
          )
        ]


encodeUrl : Url -> Json.Encode.Value
encodeUrl =
    Url.toString >> Json.Encode.string


encodeMaybe encoder maybe =
    case maybe of
        Just value ->
            encoder value

        Nothing ->
            Json.Encode.null


urlCodec : Codec Url
urlCodec =
    Codec.andThen
        (\text ->
            case Url.fromString text of
                Just url ->
                    Codec.succeed url

                Nothing ->
                    Codec.fail "Invalid url"
        )
        Url.toString
        Codec.string


build : PercyApiKey -> BuildData -> Task Http.Error BuildResponse
build (PercyApiKey apiKey) buildData =
    Http.task
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Token " ++ apiKey) ]
        , url = Url.Builder.crossOrigin percyApiDomain [ "builds" ] []
        , body = Http.jsonBody (encodeBuildData buildData)
        , resolver = Http.stringResolver (resolver buildResponseCodec)
        , timeout = Nothing
        }


resolver : Codec a -> Http.Response String -> Result Http.Error a
resolver codec =
    \response ->
        case response of
            Http.BadUrl_ url ->
                Http.BadUrl url |> Err

            Http.Timeout_ ->
                Err Http.Timeout

            Http.NetworkError_ ->
                Err Http.NetworkError

            Http.BadStatus_ metadata _ ->
                Http.BadStatus metadata.statusCode |> Err

            Http.GoodStatus_ _ body ->
                case Codec.decodeString codec body of
                    Ok ok ->
                        Ok ok

                    Err error ->
                        Json.Decode.errorToString error |> Http.BadBody |> Err


finalize : PercyApiKey -> BuildId -> Task Http.Error FinalizeResponse
finalize (PercyApiKey apiKey) (BuildId buildId) =
    Http.task
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Token " ++ apiKey) ]
        , url = Url.Builder.crossOrigin percyApiDomain [ "builds", buildId, "finalize" ] []
        , body = Http.emptyBody
        , resolver = Http.stringResolver (resolver finalizeResponseCodec)
        , timeout = Nothing
        }


type alias FinalizeResponse =
    { success : Bool }


finalizeResponseCodec : Codec FinalizeResponse
finalizeResponseCodec =
    Codec.object FinalizeResponse
        |> Codec.field "success" .success Codec.bool
        |> Codec.buildObject
