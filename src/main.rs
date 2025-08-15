use cacao::appkit::{App, MenuBarExtra, NSStatusBar};
use cacao::foundation::NSString;

fn main() {
    // Initialize the application
    let app = App::new("com.example.menu_bar_app", false).expect("Failed to create app");

    // Create a status bar item
    let status_bar = NSStatusBar::systemStatusBar();
    let status_item = status_bar.statusItemWithLength_(-1.0);

    // Create a menu bar extra with the initial text
    let menu_bar_extra = MenuBarExtra::new(NSString::from_str("Up: 1 / Down: 1"));
    status_item.setMenuBarExtra_(menu_bar_extra);

    // Run the application
    app.run();
}
