resource "google_project" "my_project" {
  name       = "my-second-project"
  project_id = "myproject-0987654"
  billing_account = data.google_billing_account.acct.id
 

}
// available in data source section in cloud billing to enable billing to project
data "google_billing_account" "acct" {
  display_name = "My Billing Account"
  open         = true
}
//cloud platform resource section for service account creation
resource "google_service_account" "service_account" {
  account_id   = "test-sa"
  display_name = "test account that avatalavpr@gmail.com can use"
  project      =  google_project.my_project.project_id

}
//bind the member or a principle to use a service account

resource "google_service_account_iam_binding" "admin-account-iam" {
  service_account_id = google_service_account.service_account.name
  role               = "roles/iam.serviceAccountUser"

  members = [
    "user:avatalavpr@gmail.com",
  ]
}
