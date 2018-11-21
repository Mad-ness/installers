#!/usr/bin/env python

import argparse
from jinja2 import Template


def main():

    parser = argparse.ArgumentParser()
    parser.add_argument("-t", "--template", required=True, type=str, help="Path to a template")
    parser.add_argument("-c", "--count", required=True, type=int, help="Number of servers to render")
    parser.add_argument("-o", "--output", required=False, type=str, default=None, help="Path to file to save a rendered template") 
    parser.add_argument("-f", "--publicnetwork", required=False, type=str, default=None, help="Public/Frontend network")
    parser.add_argument("-b", "--privatenetwork", required=False, type=str, default=None, help="Private/Backend network")
    parser.add_argument("-k", "--keypair", required=False, type=str, default=None, help="SSH key pair")



    args = parser.parse_args()

    t = Template(open(args.template, 'r').read())
    output = t.render(
        num_servers = args.count,
        frontend_network = args.publicnetwork,
        backend_network = args.privatenetwork,
        ssh_keypair = args.keypair,
    )
    if args.output != None:
        open(args.output, 'w').write(output)
    else:
        print(output)


if __name__ == "__main__":
    main()

