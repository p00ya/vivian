// manager.cpp - manage communication with Viiiiva filesystem
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

#include "manager_c_bridge.h"

#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <memory>
#include <utility>

#include "manager.hpp"

namespace {

/// C++ wrapper for the C VLManagerDelegate struct.
class ManagerDelegateBridge final : public viv::ManagerDelegate {
public:
  explicit ManagerDelegateBridge(
      void *_Nullable ctx, VLManagerDelegate delegate) noexcept
      : ctx_(ctx), delegate_(std::move(delegate)) {}

  virtual ~ManagerDelegateBridge() noexcept = default;

  int WriteValue(uint8_t const *value, size_t length) override {
    assert(delegate_.write_value != nullptr);
    return (*delegate_.write_value)(ctx_, value, length);
  }

  void DidStartWaiting() const override {
    assert(delegate_.did_start_waiting != nullptr);
    (*delegate_.did_start_waiting)(ctx_);
  }

  void DidFinishWaiting() const override {
    assert(delegate_.did_finish_waiting != nullptr);
    (*delegate_.did_finish_waiting)(ctx_);
  }

  void
  DidError(VLManagerErrorCode code, std::string const &&msg) const override {
    assert(delegate_.did_error != nullptr);
    (*delegate_.did_error)(ctx_, code, msg.c_str());
  }

  void DidParseClock(time_t posix_time) const override {
    if (delegate_.did_parse_clock != nullptr) {
      (*delegate_.did_parse_clock)(ctx_, posix_time);
    }
  }

  void DidParseDirectoryEntry(VLDirectoryEntry entry) const override {
    if (delegate_.did_parse_directory_entry != nullptr) {
      (*delegate_.did_parse_directory_entry)(ctx_, entry);
    }
  }

  void DidFinishParsingDirectory() const override {
    if (delegate_.did_finish_parsing_directory != nullptr) {
      (*delegate_.did_finish_parsing_directory)(ctx_);
    }
  }

  void DidDownloadFile(
      uint16_t index, uint8_t const *value, size_t length) const override {
    if (delegate_.did_download_file != nullptr) {
      (*delegate_.did_download_file)(ctx_, index, value, length);
    }
  }

  void DidEraseFile(uint16_t index, bool ok) const override {
    if (delegate_.did_erase_file != nullptr) {
      (*delegate_.did_erase_file)(ctx_, index, ok);
    }
  }

  void DidSetTime(bool ok) const override {
    if (delegate_.did_set_time != nullptr) {
      (*delegate_.did_set_time)(ctx_, ok);
    }
  }

private:
  void *_Nullable ctx_; // not owned
  VLManagerDelegate const delegate_;
};

} // namespace

VLCProtocolManager
VLMakeManager(void *_Nullable ctx, VLManagerDelegate delegate) {
  std::unique_ptr<viv::ManagerDelegate> delegate_bridge(
      new ManagerDelegateBridge(ctx, std::move(delegate)));
  return VLCProtocolManager{new viv::Manager(std::move(delegate_bridge))};
}

void
VLDeleteManager(VLCProtocolManager mgr) {
  delete reinterpret_cast<viv::Manager *>(mgr.manager);
}

void
VLManagerNotifyValue(VLCProtocolManager mgr, uint8_t const *value, size_t length) {
  assert(mgr.manager != nullptr);
  assert(value != nullptr);

  viv::Manager *manager = reinterpret_cast<viv::Manager *>(mgr.manager);
  return manager->NotifyValue(value, length);
}

void
VLManagerNotifyTimeout(VLCProtocolManager mgr) {
  assert(mgr.manager != nullptr);

  viv::Manager *manager = reinterpret_cast<viv::Manager *>(mgr.manager);
  return manager->NotifyTimeout();
}

void
VLManagerDownloadDirectory(VLCProtocolManager mgr) {
  assert(mgr.manager != nullptr);

  viv::Manager *manager = reinterpret_cast<viv::Manager *>(mgr.manager);
  return manager->DownloadDirectory();
}

void
VLManagerDownloadFile(VLCProtocolManager mgr, uint16_t index) {
  assert(mgr.manager != nullptr);

  viv::Manager *manager = reinterpret_cast<viv::Manager *>(mgr.manager);
  return manager->DownloadFile(index);
}

void
VLManagerEraseFile(VLCProtocolManager mgr, uint16_t index) {
  assert(mgr.manager != nullptr);

  viv::Manager *manager = reinterpret_cast<viv::Manager *>(mgr.manager);
  return manager->EraseFile(index);
}

void
VLManagerSetTime(VLCProtocolManager mgr, time_t posix_time) {
  assert(mgr.manager != nullptr);

  viv::Manager *manager = reinterpret_cast<viv::Manager *>(mgr.manager);
  return manager->SetTime(posix_time);
}
