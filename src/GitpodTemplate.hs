-- |
-- Copyright: (c) 2021 Gitpod
-- SPDX-License-Identifier: MIT
-- Maintainer: Gitpod <contact@gitpod.io>
--
-- See README for more info
module GitpodTemplate
  ( someFunc,
  )
where

import Control.Concurrent (MVar, modifyMVar, modifyMVar_, newMVar, readMVar)
import Control.Exception (finally)
import Control.Monad (forM_, forever)
import Control.Monad.IO.Class (liftIO)
import Data.Char (isPunctuation, isSpace)
import Data.Monoid (mappend)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import qualified Network.WebSockets as WS

{-
    CLIENTS
-}
type Client = (Text, WS.Connection)

type ServerState = [Client]

newServerState :: ServerState
newServerState = []

numClients :: ServerState -> Int
numClients = length

clientExists :: Client -> ServerState -> Bool
clientExists client = any ((== fst client) . fst)

addClient :: Client -> ServerState -> ServerState
addClient client clients = client : clients

removeClient :: Client -> ServerState -> ServerState
removeClient client = filter ((/= fst client) . fst)

broadcast :: Text -> ServerState -> IO ()
broadcast message clients = do
  T.putStrLn message
  forM_ clients $ \(_, conn) -> WS.sendTextData conn message

someFunc :: IO ()
someFunc = do
  putStrLn "hello"
  state <- newMVar newServerState
  WS.runServer "0.0.0.0" 3001 $ application state

-- Note that WS.ServerApp is nothing but a type synonym for WS.PendingConnection -> IO ().
-- Our application starts by accepting the connection. In a more realistic application, you probably want to check the path and headers provided by the pending request.
-- We also fork a pinging thread in the background. This will ensure the connection stays alive on some browsers.
application :: MVar ServerState -> WS.ServerApp
application state pending = do
  conn <- WS.acceptRequest pending
  WS.forkPingThread conn 30

  msg <- WS.receiveData conn
  clients <- liftIO $ readMVar state

  case msg of
    _
      | not (prefix `T.isPrefixOf` msg) ->
        WS.sendTextData conn ("Wrong announcement" :: Text)
      | any
          ($ fst client)
          [T.null, T.any isPunctuation, T.any isSpace] ->
        WS.sendTextData
          conn
          ( "Name cannot "
              `mappend` "contain punctuation or whitespace, and "
              `mappend` "cannot be empty" ::
              Text
          )
      | clientExists client clients ->
        WS.sendTextData conn ("User already exists" :: Text)
      | otherwise -> flip finally disconnect $ do
        -- We send a “Welcome!”, according to our own little protocol.
        -- We add the client to the list and broadcast the fact that he has joined.
        -- Then, we give control to the ‘talk’ function.

        liftIO $
          modifyMVar_ state $ \s -> do
            let s' = addClient client s
            WS.sendTextData conn $
              "Welcome! Users: "
                `mappend` T.intercalate ", " (map fst s)
            broadcast (fst client `mappend` " joined") s'
            return s'
        talk conn state client
      where
        prefix = "Hi! I am "
        client = (T.drop (T.length prefix) msg, conn)
        disconnect = do
          -- Remove client and return new state
          s <- modifyMVar state $ \s ->
            let s' = removeClient client s in return (s', s')
          broadcast (fst client `mappend` " disconnected") s

-- The talk function continues to read messages from a single client until he disconnects. All messages are broadcasted to the other clients.

talk :: WS.Connection -> MVar ServerState -> Client -> IO ()
talk conn state (user, _) = forever $ do
  msg <- WS.receiveData conn
  liftIO $
    readMVar state
      >>= broadcast
        (user `mappend` ": " `mappend` msg)
