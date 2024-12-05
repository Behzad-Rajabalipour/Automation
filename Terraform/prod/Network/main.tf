# remember whenever you changed the git repository files, you have to use terraform init -upgrade to not use the cache data
# 1. git add .    
# 2. git commit -m "change output"
# 2. git push prodOrigin master
# 2. terraform init -upgrade
module "vpc-dev" {
  # source = "../../dev_network_module"
  source             = "git::https://github.com/Behzad-Rajabalipour/prod_network.git"     # it's better to use https URl instead of ssh. because ssh need authentication even in public repository
  env                = var.env
  vpc_cidr           = var.vpc_cidr
  public_cidr_blocks = var.public_cidr_blocks
  private_cidr_blocks = var.private_cidr_blocks
  prefix             = var.prefix
  default_tags       = var.default_tags
}



