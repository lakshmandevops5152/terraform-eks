pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/lakshmandevops5152/terraform-eks.git'
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                ansiColor('xterm') {
                    sh '''
                        terraform init
                        terraform plan -out=tfplan
                    '''
                }
            }
        }

        stage('Approval for Apply') {
            steps {
                script {
                    def userInput = input(
                        id: 'ApplyApproval',
                        message: 'Do you want to apply the Terraform plan?',
                        parameters: [
                            [$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Approve to apply Terraform changes', name: 'Approved']
                        ]
                    )
                    if (!userInput) {
                        error("Terraform apply was not approved. Pipeline stopped.")
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                ansiColor('xterm') {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }

        stage('Approval for Destroy') {
            steps {
                script {
                    def destroyInput = input(
                        id: 'DestroyApproval',
                        message: 'Do you want to destroy the Terraform infrastructure?',
                        parameters: [
                            [$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Approve to destroy Terraform resources', name: 'DestroyApproved']
                        ]
                    )
                    if (!destroyInput) {
                        error("Terraform destroy was not approved. Pipeline stopped.")
                    }
                }
            }
        }

        stage('Terraform Destroy') {
            steps {
                ansiColor('xterm') {
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }
}
