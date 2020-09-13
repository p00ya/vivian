// Store.swift
// Copyright 2020 Dean Scarff
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Combine
import Dispatch

/// A store for application state.
///
/// The store facilitates unidirectional data flow: actions are processed
/// sequentially to modify the state, and changes to the state can be
/// observed via publishers.
///
/// ## Applying mutations
///
/// Reducers (mutations of the application state) can be applied directly
/// as closures, or may be encapsulated in `Action`s to decouple the
/// reducer logic from the caller.  The application state may change
/// between the time the reducer was dispatched and when the reducer is
/// run.
///
/// As a special case, the `@Passthrough` properties of `state` can be written
/// to directly without dispatching via the `Store`.
///
/// ## Observing state changes
///
/// Subscribers can subscribe to the `Combine` publishers on `state`.  Any
/// subscriber reading `state` must be excluded from reading it at the same
/// time as reducers are being applied.  In practice, this means
/// subscriptions must be scheduled on the same thread.
///
/// It should be noted that reducers will not behave transactionally from
/// the point of view of a subscriber by default, because subscribers will
/// receive values before the reducer has finished executing.
///
/// Subscribers should subscribe to publishers on `state` using `Store.receive`,
/// which will provide transactionality and consistency between the received
/// value and the value of `state`.
///
/// The subscribers may in turn dispatch additional reducers, or apply side
/// effects (including modifying their internal state).
///
/// ## Safeguards
///
/// To keep the code lightweight, the constraints are only enforced
/// "by convention".  There are no safeguards to prevent observers of the
/// state from mutating it directly, or for actions/reducers to
/// accidentally have side-effects.
struct Store {
  /// The application state.
  let state: State

  /// The queue for processing state reducers.
  ///
  /// The queue *must* execute tasks serially.
  let dispatchQueue: DispatchQueue

  /// Schedules the given action to be applied to the application state.
  ///
  /// - Parameter action: The action to apply.
  func dispatch(action: Action) {
    dispatchQueue.async {
      action.reduce(self.state)
    }
  }

  /// Schedules a mutation to the application state.
  ///
  /// - Parameter reducer: A function to mutate the state.  Must be
  ///     side-effect free, and execute synchronously on the caller's
  ///     thread.
  func dispatch(reducer: @escaping (_ state: State) -> Void) {
    dispatchQueue.async {
      reducer(self.state)
    }
  }

  /// Reschedules a publisher from state using the store's queue.
  ///
  /// - Parameter keyPath: Path in `State` for the publisher.
  /// - Returns: A publisher that delivers elements on the store's queue.
  func receive<P: Publisher>(_ keyPath: KeyPath<State, P>) -> Publishers.ReceiveOn<P, DispatchQueue>
  {
    return state[keyPath: keyPath].receive(on: dispatchQueue)
  }
}

/// Encapsulates an update to the application state.
protocol Action {
  /// Mutates the state.
  ///
  /// Must be side-effect free: only `state` should be mutated, and it
  /// must be mutated synchronously on the calling thread.
  ///
  /// - Parameter state: The state to mutate.
  func reduce(_ state: State)
}
