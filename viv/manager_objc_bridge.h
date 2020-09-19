// manager_objc_bridge.h - bridge C++ manager API to Objective C
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

#ifndef viv_manager_objc_bridge_h
#define viv_manager_objc_bridge_h

#ifdef __cplusplus
#include <cstdint>
#include <ctime>
#else
#include <stdint.h>
#include <time.h>
#endif

#import <Foundation/Foundation.h>

#include "compat.h"
#include "directory_entry.h"
#include "manager_error_code.h"

#pragma clang assume_nonnull begin

/// Objective C callbacks for VLOManager.
///
/// The manager will call these functions in response to notifications or
/// commands.  Client code should \b not call functions on the manager from
/// within these callbacks: they should queue such calls and process them once
/// the manager returns.
@protocol VLProtocolManagerDelegate <NSObject>

@required

/// Called when the manager wants to write a value to the Viiiiva.
///
/// \param data The GATT attribute value.
/// \return Non-zero if there was an error.
- (int)writeValue:(NSData *)data;

/// Called when the manager is waiting for a write response or value
/// notification.
///
/// No commands (\c downloadFile: etc.) should be issued to the manager until
/// the corresponding \c didFinishWaiting method is called.
- (void)didStartWaiting;

/// Called when the manager no longer waiting for a write response or value
/// notification.
- (void)didFinishWaiting;

@optional

/// Called when there was an error.
- (void)didError:(NSError *)error;

/// Called for each directory entry encountered in the directory.
///
/// The manager will call this after VLManagerDownloadDirectory.
- (void)didParseDirectoryEntry:(VLDirectoryEntry)entry;

/// Called once all directory entries have been parsed.
///
/// The manager will not call \c did_parse_directory_entry again until
/// \c downloadDirectory is next called.
- (void)didFinishParsingDirectory;

/// Called when the manager finishes downloading a file.
///
/// \param index The file's index.
/// \param data The file contents.
- (void)didDownloadFile:(uint16_t)index data:(NSData *)data;

/// Called when the manager finishes erasing file.
///
/// \param index The file's index.
- (void)didEraseFile:(uint16_t)index successfully:(BOOL)ok;

@end

/// Error domain for the libviv Manager.
extern const NSErrorDomain VLOManagerErrorDomain;

/// Event-driven management of the Viiiiva GATT service.
///
/// This interface decouples any BLE I/O from the logic that processes the
/// Viiiiva protocol embedded within the GATT values.  The manager will call its
/// delegate to write GATT values or to notify the client of results.  The
/// client code should call the "notify" functions when it receives data
/// from the GATT characteristic.
///
/// The VLOManager methods are all synchronous: they will call any functions
/// on the delegate on the same thread.  The VLOManager methods are not
/// synchronized: they should not be called concurrently without a client mutex.
/// Additionally, the callbacks must not call other VLManager functions until
/// the initial function returns.
///
/// The various commands (download etc.) will trigger a \c writeValue:
/// call on the delegate, and then enter a waiting state (signaled by calling
/// \c didStartWaiting: on the delegate).  During this time, no other commands
/// should be issued; only VLManagerNotify calls should be made.  Once the
/// manager has received and processed the expected response (or there was an
/// error), \c didFinishWaiting will be called, and other commands may be
/// issued.
@interface VLProtocolManager : NSObject {

@package

  // Actually a viv::Manager pointer; use a void pointer here to avoid a C++
  // dependency in the header.  Owned.
  void *_manager;

@private

  // Actually a ManagerDelegateBridge pointer.  Not owned.
  void *_delegateBridge;
}

/// Delegate for callbacks.
@property(nonatomic, weak, nullable) id<VLProtocolManagerDelegate> delegate;

/// Initialize a manager to call functions on \p delegate.
- (instancetype)initWithDelegate:
    (nullable id<VLProtocolManagerDelegate>)delegate NS_DESIGNATED_INITIALIZER;

/// Notifies the manager that a GATT value notification was received.
///
/// \param data The GATT attribute value.
- (void)notifyValue:(NSData *)data;

/// Notifies the manager that was waiting for a response that the response was
/// not received within a timeout period.
- (void)notifyTimeout;

/// Commands the manager to fetch and parse the directory listing.
///
/// The manager will send a write request via the delegate, then call
/// \c didStartWaiting.  After receiving the expected response and
/// value notifications, the manager will parse the directory.  It will then
/// call did_parse_directory_entry once for each valid entry found, then
/// \c didFinishParsingDirectory.  Finally, it will call
/// \c didFinishWaiting.
- (void)downloadDirectory;

/// Commands the manager to download a file.
///
/// The manager will send a write request via the delegate, then call
/// \c didStartWaiting.  After receiving the expected response
/// and value notifications, the manager will parse the file response.  It will
/// then call \c didDownloadFile.  Finally, it will call
/// \c didFinishWaitingForResponse.
- (void)downloadFile:(uint16_t)index;

/// Commands the manager to download a file.
///
/// The manager will send a write request via the delegate, then call
/// \c didStartWaiting.  After receiving the expected response
/// and value notifications, the manager will parse the erase response.  It will
/// then call did_erase_file.  Finally, it will call
/// \c didFinishWaiting.
- (void)eraseFile:(uint16_t)index;

/// Commands the manager to set the Viiiiva's time.
///
/// The manager will send a write request via the delegate, then call
/// \c didStartWaiting.  After receiving the expected response,
/// it will call \c didFinishWaiting.
- (void)setTime:(time_t)posixTime;

@end

#pragma clang assume_nonnull end

#endif /* viv_manager_objc_bridge_h */
