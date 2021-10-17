module Main exposing (main)

import Base64
import Browser
import Bytes exposing (Bytes)
import Bytes.Encode
import Html exposing (Html)
import Http
import Json.Decode exposing (Decoder)
import Json.Encode
import List.Nonempty exposing (Nonempty(..))
import SHA256
import Task exposing (Task)
import Url
import Url.Builder


key =
    PercyApiKey ""


type Msg
    = PercyResponse (Result Http.Error FinalizeResponse)


main : Program () {} Msg
main =
    Browser.element
        { init =
            \_ ->
                ( {}
                , snapshot
                    key
                    (Nonempty { name = "testtest", html = "testtest" }
                        [ { name = "testtest2", html = "<img src=\"image.png\"></img>" } ]
                    )
                    [ { filepath = "image.png"
                      , content =
                            Base64.toBytes "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"
                                |> Maybe.withDefault (Bytes.Encode.sequence [] |> Bytes.Encode.encode)
                      }
                    ]
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


type alias Snapshot =
    { name : String, html : String }


type alias PublicFiles =
    { filepath : String
    , content : Bytes
    }


snapshot : PercyApiKey -> Nonempty Snapshot -> List PublicFiles -> Task Http.Error FinalizeResponse
snapshot apiKey snapshots publicFiles =
    let
        publicFiles_ =
            List.map (\file -> ( SHA256.fromBytes file.content, file )) publicFiles
    in
    createBuild
        apiKey
        { attributes =
            { branch = "main"
            , targetBranch = "main"
            }
        , relationships = { resources = { data = [] } }
        }
        |> Task.andThen
            (\{ data } ->
                List.Nonempty.toList snapshots
                    |> List.map
                        (\snapshot_ ->
                            let
                                hash : SHA256.Digest
                                hash =
                                    SHA256.fromString htmlString

                                htmlString : String
                                htmlString =
                                    "<!DOCTYPE html>\n<html><head></head><body>"
                                        ++ snapshot_.html
                                        ++ "</body></html>"

                                filesToUpload =
                                    List.filter
                                        (\( _, file ) -> String.contains file.filepath htmlString)
                                        publicFiles_
                            in
                            createSnapshot
                                apiKey
                                data.buildId
                                { name = snapshot_.name
                                , widths = Nonempty 500 []
                                , minHeight = Nothing
                                , resources =
                                    Nonempty
                                        { id = hash
                                        , attributes =
                                            { resourceUrl = "/index.html"
                                            , isRoot = True
                                            , mimeType = Just "text/html"
                                            }
                                        }
                                        (List.map
                                            (\( fileHash, file ) ->
                                                { id = fileHash
                                                , attributes =
                                                    { resourceUrl =
                                                        List.map Url.percentEncode (String.split "/" file.filepath)
                                                            |> String.join "/"
                                                            |> (++) "/"
                                                    , isRoot = False
                                                    , mimeType = Nothing
                                                    }
                                                }
                                            )
                                            filesToUpload
                                        )
                                }
                                |> Task.andThen
                                    (\_ ->
                                        uploadResource apiKey data.buildId hash htmlString
                                            :: List.map
                                                (\( fileHash, file ) ->
                                                    uploadResourceBytes apiKey data.buildId fileHash file.content
                                                )
                                                filesToUpload
                                            |> Task.sequence
                                    )
                        )
                    |> Task.sequence
                    |> Task.andThen (\_ -> finalize apiKey data.buildId)
            )


type alias SnapshotResource =
    { id : SHA256.Digest
    , attributes :
        { -- resource filepath (probably the filepath that will be used within the webpage)
          resourceUrl : String
        , -- True if this is the html text
          isRoot : Bool
        , mimeType : Maybe String
        }
    }


percyApiDomain : String
percyApiDomain =
    "https://percy.io/api/v1"


uploadResource : PercyApiKey -> BuildId -> SHA256.Digest -> String -> Task Http.Error ()
uploadResource (PercyApiKey apiKey) (BuildId buildId) hash content =
    Http.task
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Token " ++ apiKey) ]
        , url = Url.Builder.crossOrigin percyApiDomain [ "builds", buildId, "resources" ] []
        , body = Http.jsonBody (encodeUploadResource hash content)
        , resolver = Http.stringResolver (resolver (Json.Decode.succeed ()))
        , timeout = Nothing
        }


uploadResourceBytes : PercyApiKey -> BuildId -> SHA256.Digest -> Bytes -> Task Http.Error ()
uploadResourceBytes (PercyApiKey apiKey) (BuildId buildId) hash content =
    Http.task
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Token " ++ apiKey) ]
        , url = Url.Builder.crossOrigin percyApiDomain [ "builds", buildId, "resources" ] []
        , body = Http.jsonBody (encodeUploadResourceBytes hash content)
        , resolver = Http.stringResolver (resolver (Json.Decode.succeed ()))
        , timeout = Nothing
        }


encodeUploadResource : SHA256.Digest -> String -> Json.Encode.Value
encodeUploadResource hash content =
    Json.Encode.object
        [ ( "data"
          , Json.Encode.object
                [ ( "type", Json.Encode.string "resources" )
                , ( "id", SHA256.toHex hash |> Json.Encode.string )
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


encodeUploadResourceBytes : SHA256.Digest -> Bytes -> Json.Encode.Value
encodeUploadResourceBytes hash content =
    Json.Encode.object
        [ ( "data"
          , Json.Encode.object
                [ ( "type", Json.Encode.string "resources" )
                , ( "id", SHA256.toHex hash |> Json.Encode.string )
                , ( "attributes"
                  , Json.Encode.object
                        [ ( "base64-content"
                          , Base64.fromBytes content |> Maybe.withDefault "" |> Json.Encode.string
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
        , resolver = Http.stringResolver (resolver (Json.Decode.succeed ()))
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
                        , ( "widths"
                          , List.Nonempty.toList data.widths
                                |> List.map (clamp 10 2000)
                                |> Json.Encode.list Json.Encode.int
                          )
                        , ( "minimum-height"
                          , case data.minHeight of
                                Just minHeight ->
                                    Json.Encode.int (clamp 10 2000 minHeight)

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
    { data : { buildId : BuildId }
    }


buildResponseCodec : Decoder BuildResponse
buildResponseCodec =
    Json.Decode.map BuildResponse
        (Json.Decode.field
            "data"
            (Json.Decode.map (\id -> { buildId = id })
                (Json.Decode.field "id" buildIdCodec)
            )
        )


buildIdCodec : Decoder BuildId
buildIdCodec =
    Json.Decode.string |> Json.Decode.map BuildId


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
                , ( "mimetype", encodeMaybe Json.Encode.string resource.attributes.mimeType )
                ]
          )
        ]


encodeMaybe : (a -> Json.Encode.Value) -> Maybe a -> Json.Encode.Value
encodeMaybe encoder maybe =
    case maybe of
        Just value ->
            encoder value

        Nothing ->
            Json.Encode.null


createBuild : PercyApiKey -> BuildData -> Task Http.Error BuildResponse
createBuild (PercyApiKey apiKey) buildData =
    Http.task
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Token " ++ apiKey) ]
        , url = Url.Builder.crossOrigin percyApiDomain [ "builds" ] []
        , body = Http.jsonBody (encodeBuildData buildData)
        , resolver = Http.stringResolver (resolver buildResponseCodec)
        , timeout = Nothing
        }


resolver : Decoder a -> Http.Response String -> Result Http.Error a
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
                case Json.Decode.decodeString codec body of
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


finalizeResponseCodec : Decoder FinalizeResponse
finalizeResponseCodec =
    Json.Decode.map FinalizeResponse
        (Json.Decode.field "success" Json.Decode.bool)
