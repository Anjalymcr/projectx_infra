// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
	integrations: [
		starlight({
			title: 'ProjectX-Infra',
			sidebar: [
				{
					label: 'Getting Started',
					items: [
						{ label: 'Introduction', slug: 'index' },
						{ label: 'Prerequisites', slug: 'getting-started/prerequisites' },
						{ label: 'Quickstart', slug: 'getting-started/quickstart' },
					],
				},
				{
					label: 'Architecture',
					items: [
						{ label: 'Overview', slug: 'architecture/overview' },
						{ label: 'Design Principles', slug: 'architecture/design-principles' },
						{ label: 'Networking', slug: 'architecture/networking' },
					],
				},
				{
					label: 'Infrastructure Layers',
					items: [
						{ label: 'L1: Infra (VPC)', slug: 'layers/01-infra' },
						{ label: 'L2: Storage', slug: 'layers/02-storage' },
						{ label: 'L3: IAM', slug: 'layers/03-iam' },
						{ label: 'L4: EKS', slug: 'layers/04-eks' },
					],
				},
				{
					label: 'Operations',
					items: [
						{ label: 'Deployment Guide', slug: 'operations/deployment-guide' },
						{ label: 'Makefile Reference', slug: 'operations/makefile-reference' },
						{ label: 'Destroy & Teardown', slug: 'operations/destroy-teardown' },
						{ label: 'Troubleshooting', slug: 'operations/troubleshooting' },
					],
				},
				{
					label: 'Reference',
					items: [
						{ label: 'Variables', slug: 'reference/variables' },
						{ label: 'Tagging Strategy', slug: 'reference/tags' },
						{ label: 'Environments', slug: 'reference/environments' },
					],
				},
			],
		}),
	],
});
