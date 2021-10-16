module Main exposing (build, finalize, main)

import Browser
import Codec exposing (Codec)
import Html exposing (text)
import Http
import Json.Decode
import Json.Encode
import Process
import Task exposing (Task)
import Url exposing (Url)
import Url.Builder


key =
    PercyApiKey "e7a6d7bcf5278626e7fb4af397b65ab994daed19df807c9917d1149b7543863d"


type Msg
    = PercyResponse (Result Http.Error ())


main : Program () {} Msg
main =
    Browser.element
        { init =
            \_ ->
                ( {}
                , build
                    key
                    { attributes =
                        { branch = "main"
                        , targetBranch = "main"
                        }
                    , relationships = { resources = { data = [] } }
                    }
                    |> Task.andThen
                        (\{ data } ->
                            Process.sleep 5000 |> Task.andThen (\() -> finalize key data.id)
                        )
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


type Hash64
    = Hash64 String


type alias Resource =
    { id : Hash64
    , attributes :
        { resourceUrl : Url
        , isRoot : Maybe Bool
        , mimeType : String
        }
    }


percyApiDomain : String
percyApiDomain =
    "https://percy.io/api/v1"


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
            { data : List Resource }
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


encodeResource : Resource -> Json.Encode.Value
encodeResource resource =
    Json.Encode.object
        [ ( "type", Json.Encode.string "resources" )
        , ( "id", Codec.encoder hash64Codec resource.id )
        , ( "attributes"
          , Json.Encode.object
                [ ( "resource-url", Codec.encoder urlCodec resource.attributes.resourceUrl )
                , ( "isRoot", Json.Encode.null )
                , ( "mimetype", Json.Encode.string resource.attributes.mimeType )
                ]
          )
        ]


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


hash64Codec : Codec Hash64
hash64Codec =
    Codec.string |> Codec.map Hash64 (\(Hash64 a) -> a)


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
