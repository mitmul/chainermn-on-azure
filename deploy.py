#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import datetime
import glob
import json
import os
import subprocess
import tempfile

from azure.common import credentials
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.resource.resources.models import DeploymentMode
from azure.mgmt.storage import StorageManagementClient
from azure.mgmt.storage.models import AccountSasParameters
from azure.mgmt.storage.models import Kind
from azure.mgmt.storage.models import Permissions
from azure.mgmt.storage.models import Services
from azure.mgmt.storage.models import SignedResourceTypes
from azure.mgmt.storage.models import Sku
from azure.mgmt.storage.models import StorageAccountCreateParameters
from azure.storage.blob import BlockBlobService
from azure.storage.blob import ContentSettings
from azure.storage.blob import PublicAccess

CREDENTIALS, SUBSCRIPTION_ID = credentials.get_azure_cli_credentials()


def upload_script_files(location, resource_group, account_name, share_name, container_name, restart):
    client = StorageManagementClient(CREDENTIALS, SUBSCRIPTION_ID)
    if client.storage_accounts.check_name_availability(account_name).name_available:
        result = client.storage_accounts.create(
            resource_group_name=resource_group,
            account_name=account_name,
            parameters=StorageAccountCreateParameters(
                sku=Sku('Standard_LRS'),
                kind=Kind.storage,
                location=location
            )
        )
        result.wait()
    else:
        if not restart:
            raise ValueError('{} is not available for storage account name.'.format(account_name))
        else:
            print('{} exists but continue deploying.'.format(account_name))

    # Get account key
    keys = client.storage_accounts.list_keys(resource_group, account_name)
    account_key = keys.keys[0].as_dict()['value']

    # Create public blob
    bs = BlockBlobService(account_name, account_key)
    if container_name not in [l.name for l in bs.list_containers()]:
        bs.create_container(container_name, public_access=PublicAccess.Container, fail_on_exist=False)
    # Upload script files
    urls = []
    for fn in glob.glob('scripts/*'):
        bs.create_blob_from_path(container_name, os.path.basename(fn), fn)
        url = bs.make_blob_url(container_name, os.path.basename(fn))
        urls.append(url)

    return urls


def create_resource_group(location, resource_group):
    client = ResourceManagementClient(CREDENTIALS, SUBSCRIPTION_ID)
    client.resource_groups.create_or_update(resource_group, {'location': location})


def jumpbox_deploy(resource_group, jumpbox_template, public_key, script_urls, command):
    client = ResourceManagementClient(CREDENTIALS, SUBSCRIPTION_ID)
    template = json.load(open(jumpbox_template))
    public_key = open(public_key).read().strip()
    parameters = {
        'virtualMachineName':  'jumpbox',
        'vmImage':  'Ubuntu_16.04',
        'virtualMachineSize': 'Standard_DS3_v2',
        'adminUsername': 'ubuntu',
        'adminPublicKey': public_key,
        'scriptURLs': script_urls,
        'executeCommand': command
    }
    parameters = {k: {'value': v} for k, v in parameters.items()}

    deployment_properties = {
        'mode': DeploymentMode.incremental,
        'template': template,
        'parameters': parameters
    }
    result = client.deployments.create_or_update(resource_group, 'jumpbox', deployment_properties)
    print('Deploying jumpbox...')
    result.wait()


def vmss_deploy(resource_group, vmss_template, vm_size, count, public_key, script_urls, command):
    client = ResourceManagementClient(CREDENTIALS, SUBSCRIPTION_ID)
    template = json.load(open(vmss_template))
    public_key = open(public_key).read().strip()
    parameters = {
        'virtualMachineSize': vm_size,
        'vmImage': 'Ubuntu_16.04',
        'vmPrefixName': 'chainermn',
        'instanceCount': count,
        'vnetRG': resource_group,
        'masterName': 'jumpbox',
        'adminUserName': 'ubuntu',
        'adminPublicKey': public_key,
        'scriptURLs': script_urls,
        'executeCommand': command
    }
    parameters = {k: {'value': v} for k, v in parameters.items()}

    deployment_properties = {
        'mode': DeploymentMode.incremental,
        'template': template,
        'parameters': parameters
    }
    result = client.deployments.create_or_update(resource_group, 'vmss', deployment_properties)
    print('Deploying VMSS...')
    result.wait()


def get_jumpbox_ip(resource_group):
    cmd = """ \
    az vm list-ip-addresses \
    -g {resource_group} -n jumpbox \
    --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv
    """.format(resource_group=resource_group)
    ip_address = subprocess.check_output(cmd, shell=True).decode('utf-8')
    return ip_address.strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--resource-group', '-g', type=str, default='chainermn')
    parser.add_argument('--location', '-l', type=str, default='westus2')
    parser.add_argument('--public-key-file', '-k', type=str)
    parser.add_argument('--storage-account-name', '-s', type=str, default='chainermnscripts')
    parser.add_argument('--storage-blob-name', '-b', type=str, default='scripts')
    parser.add_argument('--blob-container-name', '-o', type=str, default='scripts')
    parser.add_argument('--jumpbox-template', '-j', type=str, default='templates/jumpbox.json')
    parser.add_argument('--jumpbox-command', type=str, default='sh setup_jumpbox.sh')
    parser.add_argument('--vmss-template', '-v', type=str, default='templates/vmss.json')
    parser.add_argument('--vmss-command', type=str, default='sh setup_vmss.sh')
    parser.add_argument('--vmss-size', '-z', type=str, default='Standard_NC24r')
    parser.add_argument('--vmss-instance-count', '-n', type=int, default=1)
    parser.add_argument('--restart', '-r', action='store_true', default=False)
    args = parser.parse_args()

    create_resource_group(args.location, args.resource_group)
    script_urls = upload_script_files(
        args.location, args.resource_group, args.storage_account_name, args.storage_blob_name,
        args.blob_container_name, args.restart)
    jumpbox_deploy(args.resource_group, args.jumpbox_template, args.public_key_file, script_urls, args.jumpbox_command)

    ip_address = get_jumpbox_ip(args.resource_group)
    print('ssh -i {} ubuntu@{}'.format(os.path.splitext(args.public_key_file)[0], ip_address))

    # vmss_deploy(
    #     args.resource_group, args.vmss_template, args.vmss_size, args.vmss_instance_count, args.public_key_file,
    #     script_urls, args.vmss_command)


if __name__ == '__main__':
    main()
