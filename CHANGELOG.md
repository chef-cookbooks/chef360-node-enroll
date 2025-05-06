# chef360-node-enroll CHANGELOG

This file is used to list changes made in each version of the chef360-node-enroll cookbook.

## 1.0.0

- First Release

## 1.0.1

- Fixed node enrollment and courier job execution issues with secure Chef 360 env

## 1.0.2

- Handled the depreciated i386 package in Chef 360 downloads 

## 1.0.3

- Added few client side attributes related to cookbook enrol while registering to Chef 360

## 1.0.4

- Added support to use custom Habitat server while downloading core / node management agent on the nodes

## 1.0.5

- Modified the code to make hab-sup service to connect to user defined hab builder instead of default public builder

## 1.0.6

- Modified the code to make hab-sup service to connect to user defined hab builder instead of default public builder for Windows enrollment

## 1.0.7

- Added debug logs and passing locally generated node_id in API platform/node-accounts/v1/node

## 1.0.8

- Fixed cookbook compilation issues in Chef Client 17.x.x
- Added compliance profiles for full and partial enroll
- Handled Habitat installation on secure Chef env
- Removed the dependency of toml gem

## 1.0.9

- Added instructions to README file for obtaining secret, access key and root ca for SaaS env