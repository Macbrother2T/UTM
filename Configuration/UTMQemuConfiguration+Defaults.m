//
// Copyright © 2020 osy. All rights reserved.
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
//

#import "UTMQemuConfiguration+Constants.h"
#import "UTMQemuConfiguration+Defaults.h"
#import "UTMQemuConfiguration+Display.h"
#import "UTMQemuConfiguration+Miscellaneous.h"
#import "UTMQemuConfiguration+Networking.h"
#import "UTMQemuConfiguration+Sharing.h"
#import "UTMQemuConfiguration+System.h"

@interface UTMQemuConfiguration ()

- (NSString *)generateMacAddress;

@end

@implementation UTMQemuConfiguration (Defaults)

- (void)loadDefaults {
    self.systemArchitecture = @"x86_64";
    self.systemTarget = @"q35";
    [self loadDefaultsForTarget:@"q35" architecture:@"x86_64"];
    self.systemMemory = @512;
    if (@available(iOS 14, *)) {
        // use bootindex on new UI
        self.systemBootDevice = @"";
    } else {
        self.systemBootDevice = @"cd";
    }
    self.systemUUID = [[NSUUID UUID] UUIDString];
    self.displayUpscaler = @"linear";
    self.displayDownscaler = @"linear";
    self.consoleFont = @"Menlo";
    self.consoleFontSize = @12;
    self.consoleTheme = @"Default";
    self.networkCardMac = [UTMQemuConfiguration generateMacAddress];
    self.usbRedirectionMaximumDevices = @3;
    self.name = [NSUUID UUID].UUIDString;
    self.existingPath = nil;
    self.selectedCustomIconPath = nil;
}

- (void)loadDisplayDefaultsForTarget:(nullable NSString *)target architecture:(nullable NSString *)architecture {
    NSString *card = nil;
    if ([target hasPrefix:@"pc"] || [target hasPrefix:@"q35"]) {
        card = @"virtio-vga-gl";
    } else if ([target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) {
        card = @"virtio-ramfb-gl";
    } else if (architecture) {
        NSArray<NSString *> *cards = [UTMQemuConfiguration supportedDisplayCardsForArchitecture:architecture];
        NSString *first = cards.firstObject;
        if (first) {
            card = first;
        }
    }
    if (card.length == 0) {
        self.displayCard = @"";
        self.displayConsoleOnly = YES;
        return;
    }
    self.displayCard = card;
    self.displayConsoleOnly = NO;
}

- (void)loadSoundDefaultsForTarget:(nullable NSString *)target architecture:(nullable NSString *)architecture {
    NSString *card = nil;
    if ([target hasPrefix:@"pc"]) {
        card = @"AC97";
    } else if ([target hasPrefix:@"q35"] || [target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) {
        card = @"intel-hda";
    } else if ([target isEqualToString:@"mac99"]) {
        card = @"screamer";
    } else if (architecture) {
        NSArray<NSString *> *cards = [UTMQemuConfiguration supportedSoundCardsForArchitecture:architecture];
        NSString *first = cards.firstObject;
        if (first) {
            card = first;
        }
    }
    if (card.length == 0) {
        self.soundCard = @"";
        self.soundEnabled = NO;
        return;
    }
    self.soundCard = card;
    self.soundEnabled = YES;
}

- (void)loadNetworkDefaultsForTarget:(nullable NSString *)target architecture:(nullable NSString *)architecture {
    NSString *card = nil;
    if ([target hasPrefix:@"pc"]) {
        card = @"rtl8139";
    } else if ([target hasPrefix:@"q35"]) {
        card = @"e1000";
    } else if ([target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) {
        card = @"virtio-net-pci";
    } else if (architecture) {
        NSArray<NSString *> *cards = [UTMQemuConfiguration supportedNetworkCardsForArchitecture:architecture];
        NSString *first = cards.firstObject;
        if (first) {
            card = first;
        }
    }
    if (card.length == 0) {
        self.networkCard = @"";
        self.networkMode = @"none";
        return;
    }
    self.networkCard = card;
#if TARGET_OS_OSX
    if (@available(macOS 11.3, *)) {
        self.networkMode = @"shared";
    } else {
        self.networkMode = @"emulated";
    }
#else
    self.networkMode = @"emulated";
#endif
}

- (void)loadDefaultsForTarget:(nullable NSString *)target architecture:(nullable NSString *)architecture {
    [self loadDisplayDefaultsForTarget:target architecture:architecture];
    [self loadSoundDefaultsForTarget:target architecture:architecture];
    [self loadNetworkDefaultsForTarget:target architecture:architecture];
    if ([target hasPrefix:@"pc"] || [target hasPrefix:@"q35"]) {
        self.shareClipboardEnabled = YES;
        self.systemBootUefi = YES;
    } else if ([target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) {
        self.shareClipboardEnabled = YES;
        self.usb3Support = NO;
        self.systemBootUefi = YES;
    } else if ([target isEqualToString:@"isapc"]) {
        self.inputLegacy = YES; // no USB support
    } else {
        self.shareClipboardEnabled = NO;
        self.systemBootUefi = NO;
    }
    self.useHypervisor = self.defaultUseHypervisor;
    NSString *machineProp = [UTMQemuConfiguration defaultMachinePropertiesForTarget:target];
    if (machineProp) {
        self.systemMachineProperties = machineProp;
    } else if (self.systemMachineProperties) {
        self.systemMachineProperties = @"";
    }
    if (target && architecture) {
        self.systemCPU = [UTMQemuConfiguration defaultCPUForTarget:target architecture:architecture];
    }
}

+ (nullable NSString *)defaultMachinePropertiesForTarget:(nullable NSString *)target {
    if ([target hasPrefix:@"pc"] || [target hasPrefix:@"q35"]) {
        return @"vmport=off";
    } else if ([target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) {
        return @"highmem=off";
    } else if ([target isEqualToString:@"mac99"]) {
        return @"via=pmu";
    }
    return nil;
}

+ (NSString *)defaultDriveInterfaceForTarget:(NSString *)target architecture:(NSString *)architecture type:(UTMDiskImageType)type {
    if ([target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) {
        if (type == UTMDiskImageTypeCD) {
            return @"usb";
        } else {
            return @"virtio";
        }
    } else if ([architecture hasPrefix:@"sparc"]) {
        return @"scsi";
    }
    return @"ide";
}

+ (NSString *)defaultCPUForTarget:(NSString *)target architecture:(NSString *)architecture {
    if ([architecture isEqualToString:@"aarch64"]) {
        return @"cortex-a72";
    } else if ([architecture isEqualToString:@"arm"]) {
        return @"cortex-a15";
    } else {
        return @"default";
    }
}

@end
