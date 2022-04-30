// manager_bridge.h - bridge C++ manager API to C
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

#ifndef viv_manager_c_bridge_h
#define viv_manager_c_bridge_h

#ifdef __cplusplus
#include <cstdint>
#include <cstdlib>
#include <ctime>
#else
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#endif

#include "viv/compat.h"
#include "viv/directory_entry.h"
#include "viv/manager_error_code.h"

#ifdef __clang__
#pragma clang assume_nonnull begin
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// C callbacks for VLManager.
///
/// The manager will call these functions in response to notifications or
/// commands.  Client code should \b not call functions on the manager from
/// within these callbacks: they should queue such calls and process them once
/// the manager returns.
///
/// Null members will not be called.
struct VLCProtocolManagerDelegate {

  /// Called when the manager wants to write a value to the Viiiiva.
  ///
  /// \param value The GATT attribute value.
  /// \param length Number of bytes from \p value to write.
  /// \return Non-zero if there was an error.
  int (*write_value)(void *_Nullable ctx, uint8_t const *value, size_t length);

  /// Called when the manager is waiting for a write response or value
  /// notification.
  ///
  /// No commands (VLManagerDownload, etc.) should be issued to the manager
  /// until the corresponding \c did_finish_waiting function is called.
  void (*did_start_waiting)(void *_Nullable ctx);

  /// Called when the manager no longer waiting for a write response or value
  /// notification.
  void (*did_finish_waiting)(void *_Nullable ctx);

  /// Called when there was an error.
  ///
  /// \param message An error string.  The pointer is only valid for this call;
  /// the callee should make a copy of the string for use afterwards.
  void (*_Nullable did_error)(
      void *_Nullable ctx, VLManagerErrorCode code, char const *msg);

  /// Called when the device clock is read from the directory.
  ///
  /// The Viiiiva publishes its clock as part of the directory header.  The
  /// manager will call this after VLManagerDownloadDirectory.
  ///
  /// \param posix_time Seconds since 1970-01-01 according to the Viiiiva's
  /// clock.
  void (*_Nullable did_parse_clock)(void *_Nullable ctx, time_t posix_time);

  /// Called for each directory entry encountered in the directory.
  ///
  /// The manager will call this after VLManagerDownloadDirectory.
  void (*_Nullable did_parse_directory_entry)(
      void *_Nullable ctx, VLDirectoryEntry entry);

  /// Called once all directory entries have been parsed.
  ///
  /// The manager will not call \c did_parse_directory_entry again until
  /// VLManagerDownloadDirectory is next called.
  void (*_Nullable did_finish_parsing_directory)(void *_Nullable ctx);

  /// Called when the manager finishes downloading a file.
  ///
  /// \param index The file's index.
  /// \param value The file contents.  The pointer is only valid for this call;
  /// the callee should make a copy.
  /// \param length Number of bytes in \p value.
  void (*_Nullable did_download_file)(
      void *_Nullable ctx, uint16_t index, uint8_t const *value, size_t length);

  /// Called when the manager finishes erasing file.
  ///
  /// \param index The file's index.
  /// \param ok Non-zero if the file was erased.
  void (*_Nullable did_erase_file)(void *_Nullable ctx, uint16_t index, int ok);

  /// Called when the manager finishes setting the clock.
  ///
  /// \param ok Non-zero if the clock was set.
  void (*_Nullable did_set_time)(void *_Nullable ctx, int ok);
};
typedef struct VLCProtocolManagerDelegate VLManagerDelegate;

/// Event-driven management of the Viiiiva GATT service.
///
/// This is an opaque type; libviv clients should use the C functions to
/// interact with the manager.  The actual pointer is wrapped in a struct so
/// that the functions can be renamed to look more like an object in Swift.
///
/// This interface decouples any BLE I/O from the logic that processes the
/// Viiiiva protocol embedded within the GATT values.  The manager will call its
/// delegate to write GATT values or to notify the client of results.  The
/// client code should call the VLManagerNotify functions when it receives data
/// from the GATT characteristic.
///
/// The VLManager functions are all synchronous: they will call any functions
/// on the delegate on the same thread.  The VLManager functions are not
/// synchronized: they should not be called concurrently without a client mutex.
/// Additionally, the callbacks must not call other VLManager functions until
/// the initial function returns.
///
/// The various commands (VLManagerDownload etc.) will trigger a write_value
/// call on the delegate, and then enter a waiting state (signaled by calling
/// \c did_start_waiting) on the delegate.  During this time, no other commands
/// should be issued; only VLManagerNotify calls should be made.  Once the
/// manager has received and processed the expected response (or there was an
/// error), \c did_finish_waiting will be called, and other commands may be
/// issued.
typedef struct {
  // Opaque pointer to C++ object.
  void *_Nullable manager;
} VLCProtocolManager;

/// Creates a manager object.
///
/// The caller takes ownership of the pointer, and must call VLDeleteManager.
///
/// \param ctx Arbitrary pointer passed to all callbacks on \p delegate.
/// \param delegate A collection of callbacks for the manager.
extern VLCProtocolManager
VLMakeManager(void *_Nullable ctx, VLManagerDelegate delegate)
    CF_SWIFT_NAME(VLCProtocolManager.init(ctx:delegate:));

/// Deletes a manager object previously created with VLMakeManager.
///
/// The VLManager object is no longer valid.
extern void VLDeleteManager(VLCProtocolManager mgr)
    CF_SWIFT_NAME(VLCProtocolManager.deinitialize(self:));

/// Notifies the manager that a GATT value notification was received.
///
/// \param value The GATT attribute value.
/// \param length Length of \p value in bytes.
extern void VLManagerNotifyValue(
    VLCProtocolManager mgr, uint8_t const *value, size_t length)
    CF_SWIFT_NAME(VLCProtocolManager.notifyValue(self:value:length:));

/// Notifies the manager that was waiting for a response that the response was
/// not received within a timeout period.
extern void VLManagerNotifyTimeout(VLCProtocolManager mgr)
    CF_SWIFT_NAME(VLCProtocolManager.notifyTimeout(self:));

/// Commands the manager to fetch and parse the directory listing.
///
/// The manager will send a write request via the delegate, then call
/// \c did_start_waiting.  After receiving the expected response and
/// value notifications, the manager will parse the directory.  It will then
/// call did_parse_directory_entry once for each valid entry found, then
/// \c did_finish_parsing_directory.  Finally, it will call
/// \c did_finish_waiting.
extern void VLManagerDownloadDirectory(VLCProtocolManager mgr)
    CF_SWIFT_NAME(VLCProtocolManager.downloadDirectory(self:));

/// Commands the manager to download a file.
///
/// The manager will send a write request via the delegate, then call
/// \c did_start_waiting.  After receiving the expected response
/// and value notifications, the manager will parse the file response.  It will
/// then call \c did_download_file.  Finally, it will call
/// \c did_finish_waiting_for_response.
extern void VLManagerDownloadFile(VLCProtocolManager mgr, uint16_t index)
    CF_SWIFT_NAME(VLCProtocolManager.downloadFile(self:index:));

/// Commands the manager to download a file.
///
/// The manager will send a write request via the delegate, then call
/// \c did_start_waiting.  After receiving the expected response
/// and value notifications, the manager will parse the erase response.  It will
/// then call did_erase_file.  Finally, it will call
/// \c did_finish_waiting.
extern void VLManagerEraseFile(VLCProtocolManager mgr, uint16_t index)
    CF_SWIFT_NAME(VLCProtocolManager.eraseFile(self:index:));

/// Commands the manager to set the Viiiiva's time.
///
/// The manager will send a write request via the delegate, then call
/// \c did_start_waiting.  After receiving the expected response,
/// it will call \c did_set_time and then \c did_finish_waiting.
extern void VLManagerSetTime(VLCProtocolManager mgr, time_t posix_time)
    CF_SWIFT_NAME(VLCProtocolManager.setTime(self:posixTime:));

#ifdef __cplusplus
} // extern "C"
#endif

#ifdef __clang__
#pragma clang assume_nonnull end
#endif

#endif /* viv_manager_c_bridge_h */
