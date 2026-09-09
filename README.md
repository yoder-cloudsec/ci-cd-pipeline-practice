**CI/CD Pipeline for Terraform (GitHub Actions)**  
A fully automated CI/CD pipeline that runs terraform plan and terraform apply on every push to main — no manual AWS CLI or console interaction required to deploy infrastructure changes.  
***Companion project:*** * *[ *aws-multi-tier-architecture-terraform* * — the* * infrastructure this pipeline pattern is designed to eventually manage. This repo was deliberately built against a trivial, near-zero-cost resource (a single S3 bucket) first, to learn pipeline mechanics without risking or complicating a real architecture.*](https://github.com/yoder-cloudsec/aws-multi-tier-architecture-terraform "https://github.com/yoder-cloudsec/aws-multi-tier-architecture-terraform")  
**What This Project Demonstrates**  
- **Automated CI/CD with GitHub Actions** - infrastructure changes deploy automatically on push, with no human running Terraform commands by hand  
- **Secure credential handling** - a dedicated, scoped IAM identity for the pipeline (not a personal user), with credentials stored in GitHub Secrets and injected only at runtime, never committed or logged  
- **Remote state management** - S3 backend with locking, so every pipeline run and every local machine reads and writes the same source of truth  
- **Current, modern locking approach** - migrated from the legacy DynamoDB-based locking pattern to Terraform's native S3 lockfile locking (use_lockfile, GA since Terraform 1.11), understanding why the older pattern still appears in most existing tutorials and production codebases  
- **Full automation, not partial** - plan and apply both run without manual approval, appropriate for this low-stakes practice environment (see [Design Decisions for when this would change)](#anchor-1 "#anchor-1")  
**Tech Stack**  
| | |  
|-|-|  
| **Component** | **Tool** |   
| Infrastructure | Terraform (AWS provider) |   
| CI/CD | GitHub Actions |   
| Remote State | S3 (with native lockfile locking) |   
| Credential Management | GitHub Secrets, dedicated IAM user |   
| Practice Resource | S3 bucket (near-zero cost, safe to create/destroy repeatedly) |   
   
**Pipeline Overview**  
git push → GitHub Actions triggered → runner provisioned  
    → checkout code → install Terraform → terraform init  
    → terraform plan → terraform apply -auto-approve  
   
Every step runs on a fresh, temporary GitHub-hosted runner. Nothing persists between runs except what's explicitly stored in remote state.  
**The Debugging Journey**  
This project's build was noticeably harder than the initial Terraform infrastructure rebuild and deliberately so, since CI/CD introduces a category of problem that a single local machine never surfaces: **state and environment consistency across independent, ephemeral executions.** Below is how I boned it, then fixed it.  
**1. First pipeline run failed on credentials**  
The very first workflow run correctly failed with No valid credential sources found. This was intentional and diagnostic: it confirmed the trigger, checkout, and Terraform install steps all worked correctly *before* credentials were ever introduced, isolating the one missing piece cleanly rather than debugging several unknowns at once.  
**2. "1 to add" for a resource that already existed**  
After wiring in GitHub Secrets and getting a successful first apply, a second push showed terraform plan reporting 1 to add for a bucket that was already live in AWS. The cause: each GitHub Actions runner is a completely fresh, isolated machine with no memory of any previous run,  including no access to the state file created (and destroyed along with the runner) during the prior run. Proceeding to apply correctly failed with BucketAlreadyOwnedByYou, since AWS itself remembered the bucket even though Terraform's ephemeral, runner-local state didn’t.  
**3. Local **terraform destroy ** silently did nothing**  
After the above failure, running terraform destroy locally reported No changes. No objects need to be destroyed  despite the bucket still existing in AWS. Root cause: the local machine's own state file had already been emptied by an earlier destroy, run *before* the pipeline's first successful apply had ever created the bucket. Local state, remote reality, and the pipeline's now-discarded runner state had all drifted independently. State Drift is the devil. Resolved by deleting the orphaned bucket manually via the console (a pragmatic fix for a disposable demo resource, though terraform import is the correct approach for reclaiming state ownership of real production resources in this situation.)  
**4. Building remote state and hitting the "bootstrap problem"**  
The actual fix for the above: a shared S3 backend (plus locking) so every runner and local machine read/write the same state file. This showed me a Terraform chicken-and-egg problem: you can't use Terraform to create the very backend Terraform needs in order to track what it creates. Solved by provisioning the state bucket and lock table as a one-time, separately-managed bootstrap project, intentionally never torn down.  
**5. Deprecated locking pattern then migrated to the current approach**  
After wiring in DynamoDB-based state locking, Terraform surfaced a deprecation warning pointing at use_lockfile, S3's newer native locking mechanism (GA as of Terraform 1.11, removing the need for a separate DynamoDB table entirely). Rather than ignore the warning, I migrated the backend configuration and deleted the DynamoDB table — a deliberate choice to build with the current, modern approach rather than the outdated-but-still-common pattern, while understanding both.  
**6. Local **terraform init ** broke after the migration but pipeline didn't**  
Immediately after switching to use_lockfile, the local machine failed with Error: Backend configuration changed, while the very next GitHub Actions run succeeded without issue. A fresh runner has no prior backend configuration cached anywhere to conflict with, so a changed backend is simply its *first* configuration, not a  *change*. My computer, however, retained a .terraform/ folder from the original init, which correctly flagged a mismatch against the new config. Resolved locally with terraform init -reconfigure.  
**Design Decisions**  
**Why fully automatic apply, no manual approval gate?**  
   
 Appropriate here because the practice resource is trivial, low-cost, and disposable. In a production pipeline managing real infrastructure, this step would typically require a manual approval (via GitHub Environments or a similar gate) before apply runs, especially against anything costly to misconfigure.  
**Why a dedicated IAM user for the pipeline instead of reusing a personal one?**  
   
 Limits blast radius if credentials ever leak, and makes it possible to reason clearly about exactly what the pipeline can and cannot do, independent of any individual's personal access. I still gave it full Admin Access, though it should be limited down to S3 (and formerly DynamoDB) only.  
**Why S3-native locking instead of DynamoDB?**  
   
 Fewer moving parts, no separate always-on resource to manage, and it's the direction Terraform itself is moving (DynamoDB locking is deprecated as of Terraform 1.11). DynamoDB locking was still worth learning first, but if my project is to be simple, it should at least be up-to-date.  
**What I'd Add for Production Use**  
- Manual approval gate before apply (via GitHub Environments)  
- Scope the pipeline's IAM user down from AdministratorAccess to only the specific permissions it needs  
- Run plan on pull requests (posting output as a PR comment for review) rather than only on direct pushes to main  
- Point this same pipeline pattern at the real multi-tier architecture repo, now that the mechanics are proven  
**Author's Note**  
This project was intentionally built against a trivial S3 bucket rather than real infrastructure, specifically so that pipeline and state-management mistakes could happen safely and cheaply. Nearly every meaningful lesson here came from something breaking in an informative way: ephemeral runner state, state drift, a deprecated locking pattern - rather than from a clean first attempt. “Success is a lousy teacher” or whatever.  
