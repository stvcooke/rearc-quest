# A quest in the clouds

I have shortened the README to only contain the request and fulfillment criteria, and some explanations on what I've done.

### Q. What do i have to do ?
#####   1) Deploy the app in AWS and find the secret page. Use Linux 64-bit as your OS (Amazon Linux preferred)
#####   2) Deploy the app in a Docker container. Use `node:10` as the base image
#####   3) Inject an environment variable (SECRET_WORD) in the docker container. The value of SECRET_WORD should be the secret word discovered on the secret page
#####   4) Deploy a loadbalancer in front of the app
#####   5) Complete "Terraform"ing and/or "Cloudformation"ing the entire stack for "single click" deployment (Use the latest version of Terraform available at the time)
#####   6) Add TLS (https). Its OK to use locally generated certs.

### Q. How do i know i have solved these stages ?
#####  Each stage can be tested as follows (where <ip_or_host> is the location where the app is deployed)
#####   1) AWS/Secret page - `http(s)://<ip_or_host>[:port]/`
#####   2) Docker - `http(s)://<ip_or_host>[:port]/docker`
#####   3) SECRET_WORD env variable - `http(s)://<ip_or_host>[:port]/secret_word`
#####   4) Loadbalancer - `http(s)://<ip_or_host>[:port]/loadbalanced`
#####   5) Terraform and/or Cloudformation - we will test your submitted templates in our AWS account
#####   6) TLS - `http(s)://<ip_or_host>[:port]/tls`

## Creating the stacks and executing the terraform code.
I refactored the code to use less variables, moved the ECR repository creation to CloudFormation, and created two scripts, `creation.sh` and `deletion.sh`. They take the same arguments, a prefix and a domain. The `prefix` should probably be unique, I would recommend "stvcooke-quest". Please use a domain that you have permissions to edit in Route53, and it'll append the prefix to the domain name.

From the root directory:
```
./creation.sh stvcooke-quest example.com
```

The `deletion.sh` script assumes you have boto3 installed, because deleting buckets is not easy. If you don't, I use virtualenv. Skip the python steps if boto3 is already installed on your system.

From root directory:
```
python3 -m venv venv
source venv/bin/activate
pip install boto3

./deletion.sh stvcooke-quest example.com
```

## My attempts
I had issues with step 1. You can find the attempts in the `ec2` folder. I'm not very proud of it, but it's there. I've always had issues with user data.

As for the rest of the steps, I containerized the application using the `Dockerfile` found in the root of the repository, then created the ECR repository and uploaded it there. Then I finished writing the rest of the Terraform code by creating an ECS cluster, some tasks and services, and then throwing a load balancer in front of it. I never got the "Successful Docker" message because, I assume, I didn't run it on Docker on an ec2 instance.

In the `cloudformation` directory, you'll find the remote state, vpc and ecr CloudFormation files. The remote state outputs will need to be hardcoded in the backend configuration in `ecs/main.tf` unless you use the `creation.sh` and `deletion.sh` scripts. I did try to put these in as variables, but Terraform didn't appreciate that, understandably. If this were in some capacity that I was able to devote more time to, I'd use a template file set up by the CI/CD pipeline to configure the backend to be a bit more dynamic. You will also find an `empty-stack.yml` which creates no resources. I use it to simplify CloudFormation stack creation.

Finally, the failed `stvcooke/rearc-quest-infra` repository. A few years back, I read about a Terraform deployment technique when I first learned about Github Actions that revolved around a minimal permissions user deploying a `terraform plan` output to an s3 bucket. This would trigger a lambda function that picked up the plan, and with a lot more permissions, execute the plan. There was typically enough space found in the lambda's `/tmp` to install Terraform, download the plan, and execute it. I took this opportunity to really check in on this.

The problem was, Terraform had changed and now needed to have the source code in order to do a `terraform init` to install the modules and run the `terraform apply`. Hence, the failed repository. It's abandoned, and will be archived after we talk about it. It has three major parts:
- `src/service.py` which is the python3 version of the code used way back.
- `tf-executor` which would set up the s3 trigger and lambda.
- `tf-planner` which creates the s3 drop bucket and iam roles for the github action user.
I put the github workflow using the `tf-planner` iam user in there under `workflows` and not under the usual `.github` directory that would trigger the actions.

## Lessons learned
1. Making security unobtrusive is hard. I tried implementing checkov (https://github.com/bridgecrewio/checkov) into the github actions, and it really slowed things down. There are definite changes I'd make to the Github Action that uses it. A major selling point for me was `checkov` could use the `terraform plan` output to get specific on what would be a security vulnerability, but the action doesn't allow for that. It's just static code analysis. Requiring all checks to pass, but some of them just not being ideal (such as versioning a log bucket) really slowed things down as I added in exceptions just to make that type of stuff pass.
1. A custom terraform deployer is more effort than I first thought. It would be ideal to contain all permissions inside AWS, but I think I'd want to attach an few GB EBS volume to the lambda in order to download everything and `terraform init`, and that would probably slow it down a lot.
1. I thought there was a security vulnerability as found with `njsscan`, and tried replacing the `exec()` calls with `execFile()`, but that broke the program. I then tried to pass in some phony headers to my localhost:3000 but was never able to get some execution, probably due to not figuring out how to escape quotation marks adequately enough using `curl`.
