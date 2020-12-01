// Copyright 2020 IOTA Stiftung
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
// the License. You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and limitations under the License.

use crate::error::QueryResult;
use crate::message::{MailboxRecord, Request, Response};
#[cfg(feature = "kademlia")]
use libp2p::kad::KademliaEvent;
#[cfg(feature = "kademlia")]
use libp2p::{core::Multiaddr, kad::QueryId};
use libp2p::{
    core::PeerId,
    request_response::{RequestId, ResponseChannel},
};

pub trait CodecContext {
    fn send_request(&mut self, peer_id: &PeerId, request: Request) -> RequestId;

    fn send_response(&mut self, response: Response, channel: ResponseChannel<Response>);

    #[cfg(feature = "kademlia")]
    fn get_record(&mut self, key_str: String) -> QueryId;

    #[cfg(feature = "kademlia")]
    fn put_record_local(&mut self, record: MailboxRecord) -> QueryResult<QueryId>;

    fn print_known_peer(&mut self);

    #[cfg(feature = "kademlia")]
    fn kad_add_address(&mut self, peer_id: &PeerId, addr: Multiaddr);

    #[cfg(feature = "kademlia")]
    fn kad_bootstrap(&mut self) -> QueryResult<QueryId>;
}

pub trait Codec {
    fn handle_request_msg(ctx: &mut impl CodecContext, request: Request, channel: ResponseChannel<Response>);
    fn handle_response_msg(ctx: &mut impl CodecContext, response: Response, request_id: RequestId);
    #[cfg(feature = "kademlia")]
    fn handle_kademlia_event(ctx: &mut impl CodecContext, result: KademliaEvent);
}
