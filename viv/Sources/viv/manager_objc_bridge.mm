// manager_objc_bridge.mm
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

#import "viv/manager_objc_bridge.h"

#import <Foundation/Foundation.h>
#include <memory>

#include "viv/manager.hpp"

using viv::Manager;

const NSErrorDomain VLOManagerErrorDomain = @"VLOManagerErrorDomain";

static NSString *const VLOUserInfoMessageKey = @"message";

/// Wrapper for errors from libviv, with custom description.
@interface VLOError : NSError
- (instancetype)initWithCode:(VLManagerErrorCode)code
                     message:(NSString *)message;

@end

@implementation VLOError

- (instancetype)initWithCode:(VLManagerErrorCode)code
                     message:(NSString *)message {
  self = [super initWithDomain:VLOManagerErrorDomain
                          code:code
                      userInfo:@{VLOUserInfoMessageKey : message}];
  return self;
}

- (NSString *)localizedDescription {
  return self.userInfo[VLOUserInfoMessageKey];
}

@end

namespace {

/// Implementation of the C++ delegate interface that forwards to the
/// Objective C delegate.
class ManagerDelegateBridge final : public viv::ManagerDelegate {
public:
  /// Creates a bridge to forward callbacks to the given delegate.
  ///
  /// \param delegate The Objective C delegate to receive callbacks.
  /// Only a weak reference is held (caller retains ownership).
  explicit ManagerDelegateBridge(
      id<VLProtocolManagerDelegate> delegate) noexcept
      : delegate_(delegate) {}

  virtual ~ManagerDelegateBridge() noexcept = default;

  void SetDelegate(id<VLProtocolManagerDelegate> delegate) {
    delegate_ = delegate;
  }

  int WriteValue(uint8_t const *value, size_t length) override {
    NSData *data = [NSData dataWithBytes:value length:length];
    return [delegate_ writeValue:data];
  }

  void DidStartWaiting() const override { [delegate_ didStartWaiting]; }

  void DidFinishWaiting() const override { [delegate_ didFinishWaiting]; }

  void
  DidError(VLManagerErrorCode code, std::string const &&msg) const override {
    if ([delegate_ respondsToSelector:@selector(didError:)]) {
      NSString *message = [NSString stringWithUTF8String:msg.c_str()];
      VLOError *error = [[VLOError alloc] initWithCode:code message:message];
      [delegate_ didError:error];
    }
  }

  void DidParseClock(time_t posix_time) const override {
    if ([delegate_ respondsToSelector:@selector(didParseClock:)]) {
      [delegate_ didParseClock:posix_time];
    }
  }

  void DidParseDirectoryEntry(VLDirectoryEntry entry) const override {
    if ([delegate_ respondsToSelector:@selector(didParseDirectoryEntry:)]) {
      [delegate_ didParseDirectoryEntry:entry];
    }
  }

  void DidFinishParsingDirectory() const override {
    if ([delegate_ respondsToSelector:@selector(didFinishParsingDirectory)]) {
      [delegate_ didFinishParsingDirectory];
    }
  }

  void DidDownloadFile(
      uint16_t index, uint8_t const *value, size_t length) const override {
    if ([delegate_ respondsToSelector:@selector(didDownloadFile:data:)]) {
      NSData *data = [NSData dataWithBytes:value length:length];
      [delegate_ didDownloadFile:index data:data];
    }
  }

  void DidEraseFile(uint16_t index, bool ok) const override {
    if ([delegate_ respondsToSelector:@selector(didEraseFile:successfully:)]) {
      [delegate_ didEraseFile:index successfully:ok];
    }
  }

  void DidSetTime(bool ok) const override {
    if ([delegate_ respondsToSelector:@selector(didSetTime:)]) {
      [delegate_ didSetTime:ok];
    }
  }

private:
  __weak id<VLProtocolManagerDelegate> delegate_;
};

} // namespace

@implementation VLProtocolManager

/// Returns the C++ manager associated with the given Objective C manager.
static inline Manager *
GetManager(VLProtocolManager *manager) {
  return reinterpret_cast<Manager *>(manager->_manager);
}

static inline ManagerDelegateBridge *
GetDelegateBridge(VLProtocolManager *manager) {
  return reinterpret_cast<ManagerDelegateBridge *>(manager->_delegateBridge);
}

- (instancetype)init {
  return [self initWithDelegate:nil];
}

- (instancetype)initWithDelegate:
    (nullable id<VLProtocolManagerDelegate>)delegate {
  self = [super init];
  _delegate = delegate;
  auto delegateBridge = std::make_unique<ManagerDelegateBridge>(delegate);
  // Hold a cheeky pointer to delegateBridge so that we can override
  // the Objective C delegate.  The manager (and therefore the
  // delegateBridge) are tied to this object's lifetime.
  _delegateBridge = delegateBridge.get();
  _manager = new Manager(std::move(delegateBridge));
  return self;
}

- (void)setDelegate:(nullable id<VLProtocolManagerDelegate>)delegate {
  _delegate = delegate;
  auto *delegateBridge = GetDelegateBridge(self);
  delegateBridge->SetDelegate(delegate);
}

- (void)dealloc {
  _delegateBridge = nullptr;
  delete GetManager(self);
}

- (void)notifyValue:(NSData *)data {
  GetManager(self)->NotifyValue(
      reinterpret_cast<const uint8_t *>(data.bytes), data.length);
}

- (void)notifyTimeout {
  GetManager(self)->NotifyTimeout();
}

- (void)downloadDirectory {
  GetManager(self)->DownloadDirectory();
}

- (void)downloadFile:(uint16_t)index {
  GetManager(self)->DownloadFile(index);
}

- (void)eraseFile:(uint16_t)index {
  GetManager(self)->EraseFile(index);
}

- (void)setTime:(time_t)posixTime {
  GetManager(self)->SetTime(posixTime);
}

@end
