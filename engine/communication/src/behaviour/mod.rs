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

mod protocol;
#[cfg(feature = "mdns")]
use crate::error::QueryError;
use crate::{
    error::QueryResult,
    message::{Request, Response},
};
use core::{iter, marker::PhantomData, str::FromStr};
#[cfg(feature = "mdns")]
use libp2p::mdns::{Mdns, MdnsEvent};
use libp2p::{
    build_tcp_ws_noise_mplex_yamux,
    core::{connection::ListenerId, Multiaddr, PeerId},
    identity::Keypair,
    request_response::{
        ProtocolSupport, RequestId, RequestResponse, RequestResponseConfig, RequestResponseEvent, ResponseChannel,
    },
    swarm::{
        ExpandedSwarm, IntoProtocolsHandler, NetworkBehaviour, NetworkBehaviourEventProcess, ProtocolsHandler, Swarm,
    },
    NetworkBehaviour,
};
use protocol::{MessageCodec, MessageProtocol};
// TODO: support no_std
use std::{
    collections::btree_map::{BTreeMap, Keys},
    marker::Send,
};
mod structs_proto {
    include!(concat!(env!("OUT_DIR"), "/structs.pb.rs"));
}

pub type P2PNetworkSwarm<C>= ExpandedSwarm<
     P2PNetworkBehaviour<C>,
     <<<P2PNetworkBehaviour<C> as NetworkBehaviour>::ProtocolsHandler as IntoProtocolsHandler>::Handler as ProtocolsHandler>::InEvent,
     <<<P2PNetworkBehaviour<C> as NetworkBehaviour>::ProtocolsHandler as IntoProtocolsHandler>::Handler as ProtocolsHandler>::OutEvent,
     <P2PNetworkBehaviour<C> as NetworkBehaviour>::ProtocolsHandler,
     PeerId,
>;

/// Interface for the communication with the swarm
pub trait SwarmContext {
    fn send_request(&mut self, peer_id: &PeerId, request: Request) -> RequestId;

    fn send_response(&mut self, response: Response, channel: ResponseChannel<Response>);

    #[cfg(feature = "mdns")]
    fn get_active_mdns_peers(&mut self) -> Vec<PeerId>;
}

/// Codec that describes a custom behaviour for inbound events from the swarm.
pub trait InboundEventCodec {
    fn handle_request_response_event(swarm: &mut impl SwarmContext, event: RequestResponseEvent<Request, Response>);
}

#[derive(NetworkBehaviour)]
pub struct P2PNetworkBehaviour<C: InboundEventCodec + Send + 'static> {
    #[cfg(feature = "mdns")]
    mdns: Mdns,
    msg_proto: RequestResponse<MessageCodec>,
    #[behaviour(ignore)]
    inner: PhantomData<C>,
    #[behaviour(ignore)]
    peers: BTreeMap<PeerId, Multiaddr>,
}

impl<C: InboundEventCodec + Send + 'static> SwarmContext for P2PNetworkBehaviour<C> {
    fn send_request(&mut self, peer_id: &PeerId, request: Request) -> RequestId {
        self.msg_proto.send_request(peer_id, request)
    }

    fn send_response(&mut self, response: Response, channel: ResponseChannel<Response>) {
        self.msg_proto.send_response(channel, response)
    }
    #[cfg(feature = "mdns")]
    /// Get the peers discovered by mdns
    fn get_active_mdns_peers(&mut self) -> Vec<PeerId> {
        let mut peers = Vec::new();
        for peer_id in self.mdns.discovered_nodes() {
            peers.push(peer_id.clone());
        }
        peers
    }
}

impl<C: InboundEventCodec + Send + 'static> P2PNetworkBehaviour<C> {
    /// Creates a new P2PNetworkbehaviour that defines the communication with the libp2p swarm.
    /// It combines the following protocols from libp2p:
    /// - mDNS for peer discovery within the local network
    /// - RequestResponse Protocol for sending request and reponse messages. This stronghold-communication library
    ///   defines a custom version of this protocol that for sending pings, string-messages and key-value-records.
    ///
    /// # Example
    /// ```no_run
    /// use communication::{
    ///     behaviour::{InboundEventCodec, P2PNetworkBehaviour, SwarmContext},
    ///     error::QueryResult,
    ///     message::{Request, Response},
    /// };
    /// use libp2p::{
    ///     core::{identity::Keypair, Multiaddr, PeerId},
    ///     request_response::{RequestId, RequestResponseEvent, ResponseChannel},
    /// };
    ///
    /// let local_keys = Keypair::generate_ed25519();
    ///
    /// struct Handler();
    /// impl InboundEventCodec for Handler {
    ///     fn handle_request_response_event(
    ///         _swarm: &mut impl SwarmContext,
    ///         _event: RequestResponseEvent<Request, Response>,
    ///     ) {
    ///     }
    /// }
    ///
    /// let mut swarm = P2PNetworkBehaviour::<Handler>::new(local_keys).unwrap();
    /// ```
    pub fn new(local_keys: Keypair) -> QueryResult<P2PNetworkSwarm<C>> {
        #[allow(unused_variables)]
        let local_peer_id = PeerId::from(local_keys.public());

        #[cfg(feature = "mdns")]
        let mdns =
            Mdns::new().map_err(|_| QueryError::ConnectionError("Could not build mdns behaviour".to_string()))?;

        // Create RequestResponse behaviour with MessageProtocol
        let msg_proto = {
            let cfg = RequestResponseConfig::default();
            let protocols = iter::once((MessageProtocol(), ProtocolSupport::Full));
            RequestResponse::new(MessageCodec(), protocols, cfg)
        };

        let behaviour = P2PNetworkBehaviour::<C> {
            #[cfg(feature = "mdns")]
            mdns,
            msg_proto,
            inner: PhantomData,
            peers: BTreeMap::new(),
        };
        let transport = build_tcp_ws_noise_mplex_yamux(local_keys)
            .map_err(|_| QueryError::ConnectionError("Could not build transport layer".to_string()))?;
        Ok(Swarm::new(transport, behaviour, local_peer_id))
    }

    pub fn start_listening(
        swarm: &mut P2PNetworkSwarm<C>,
        listening_addr: Option<Multiaddr>,
    ) -> QueryResult<ListenerId> {
        let addr = listening_addr
            .or_else(|| Multiaddr::from_str("/ip4/0.0.0.0/tcp/0").ok())
            .ok_or_else(|| QueryError::ConnectionError("Invalid Multiaddr".to_string()))?;
        Swarm::listen_on(swarm, addr).map_err(|e| QueryError::ConnectionError(format!("{}", e)))
    }

    /// Dials a peer if it is either in the same network or has a public IP Address
    pub fn dial_addr(swarm: &mut P2PNetworkSwarm<C>, peer_addr: Multiaddr) -> QueryResult<()> {
        Swarm::dial_addr(swarm, peer_addr.clone())
            .map_err(|_| QueryError::ConnectionError(format!("Could not dial addr {}", peer_addr)))
    }

    /// Prints the multi-addresses that this peer is listening on within the local network.
    pub fn get_listeners(swarm: &mut P2PNetworkSwarm<C>) -> impl Iterator<Item = &Multiaddr> {
        Swarm::listeners(swarm)
    }

    pub fn add_peer(&mut self, peer_id: PeerId, addr: Multiaddr) {
        self.peers.insert(peer_id, addr);
    }

    pub fn get_peer_addr(&self, peer_id: &PeerId) -> Option<&Multiaddr> {
        self.peers.get(peer_id)
    }

    pub fn get_all_peers(&self) -> Keys<PeerId, Multiaddr> {
        self.peers.keys()
    }
}

#[cfg(feature = "mdns")]
impl<C: InboundEventCodec + Send + 'static> NetworkBehaviourEventProcess<MdnsEvent> for P2PNetworkBehaviour<C> {
    // Called when `mdns` produces an event.
    #[allow(unused_variables)]
    fn inject_event(&mut self, event: MdnsEvent) {
        if let MdnsEvent::Discovered(list) = event {
            for (peer_id, multiaddr) in list {
                self.add_peer(peer_id, multiaddr);
            }
        }
    }
}

impl<C: InboundEventCodec + Send + 'static> NetworkBehaviourEventProcess<RequestResponseEvent<Request, Response>>
    for P2PNetworkBehaviour<C>
{
    // Called when the protocol produces an event.
    fn inject_event(&mut self, event: RequestResponseEvent<Request, Response>) {
        C::handle_request_response_event(self, event);
    }
}

#[cfg(test)]
struct DummyHandler;
#[cfg(test)]
impl InboundEventCodec for DummyHandler {
    fn handle_request_response_event(_swarm: &mut impl SwarmContext, _event: RequestResponseEvent<Request, Response>) {}
}

#[cfg(test)]
fn mock_swarm() -> P2PNetworkSwarm<DummyHandler> {
    let local_keys = Keypair::generate_ed25519();
    P2PNetworkBehaviour::<DummyHandler>::new(local_keys).unwrap()
}

#[cfg(test)]
fn mock_addr() -> Multiaddr {
    Multiaddr::from_str("/ip4/127.0.0.1/tcp/0").unwrap()
}

#[test]
fn test_new_behaviour() {
    let local_keys = Keypair::generate_ed25519();
    let swarm = P2PNetworkBehaviour::<DummyHandler>::new(local_keys.clone()).unwrap();
    assert_eq!(
        &PeerId::from_public_key(local_keys.public()),
        Swarm::local_peer_id(&swarm)
    );
    assert!(swarm.get_all_peers().next().is_none());
}

#[test]
fn test_add_peer() {
    let mut swarm = mock_swarm();
    let peer_id = PeerId::random();
    swarm.add_peer(peer_id.clone(), mock_addr());
    assert!(swarm.get_peer_addr(&peer_id).is_some());
    assert!(swarm.get_all_peers().any(|p| p == &peer_id));
}
