require 'xcodeproj'

# Open the existing Xcode project
project_file = "stts.xcodeproj"
project = Xcodeproj::Project.open(project_file)

# Sort the main group (recursive)
project.main_group.sort_recursively_by_type

# Save
project.save
