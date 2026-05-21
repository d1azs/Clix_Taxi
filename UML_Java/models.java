import java.util.UUID;
import java.util.List;
import java.util.Date;
import java.math.BigDecimal;

// ENUMS
enum Role { PASSENGER, DRIVER, DISPATCHER }
enum DriverStatus { ONLINE, OFFLINE }
enum OrderStatus { PENDING, ACCEPTED, EN_ROUTE, IN_PROGRESS, COMPLETED, CANCELLED }
enum RequiredClass { ECONOMY, PREMIUM, BUSINESS, MINIVAN }
enum VehicleClass { ECONOMY, PREMIUM, BUSINESS, MINIVAN }
enum KYCStatus { PENDING, APPROVED, REJECTED }
enum CancellationReason { PASSENGER_REQUEST, DRIVER_REQUEST, NO_DRIVERS, DISPATCHER_OVERRIDE, SYSTEM }

// CLASSES
class User {
    private UUID id;
    private String phone_number;
    private String first_name;
    private String last_name;
    private List<Role> roles;
    private Boolean is_active;
    private Boolean is_staff;
    private Date created_at;
    
    // Relationships
    private DriverProfile driverProfile;
    private List<Review> writtenReviews;

    public Boolean has_role(String role) { return false; }
    public Boolean is_passenger() { return false; }
    public Boolean is_driver() { return false; }
    public Boolean is_dispatcher() { return false; }
}

class DriverProfile {
    private UUID id;
    private DriverStatus status;
    private BigDecimal rating;
    private Integer total_trips;
    private BigDecimal total_earnings;
    private Float current_lat;
    private Float current_lng;
    
    // Relationships
    private List<Vehicle> vehicles;
    private List<KYCDocument> kycDocuments;
    private DriverRanking ranking;
    private List<VirtualQueueEntry> queueEntries;
    private List<Review> receivedReviews;
}

class KYCDocument {
    private UUID id;
    private String id_card_image_url;
    private String license_image_url;
    private String registration_image_url;
    private KYCStatus status;
    private String feedback_note;
    private Date submitted_at;
    private Date reviewed_at;
}

class DriverRanking {
    private UUID id;
    private BigDecimal acceptance_rate;
    private BigDecimal avg_response_time;
    private BigDecimal composite_score;
    private Date updated_at;
}

class Vehicle {
    private UUID id;
    private String make_model;
    private String license_plate;
    private VehicleClass vehicle_class;
    private String color;
    private Boolean is_pet_friendly;
    private Boolean has_child_seat;
    private Boolean is_wheelchair_accessible;
    private Boolean is_active;
}

class Order {
    private UUID id;
    private String pickup_address;
    private String dropoff_address;
    private Float pickup_lat;
    private Float pickup_lng;
    private Float dropoff_lat;
    private Float dropoff_lng;
    private Date pickup_time;
    private RequiredClass required_class;
    private OrderStatus status;
    private BigDecimal estimated_price;
    private BigDecimal upfront_price;
    private BigDecimal commission_deduction;
    private BigDecimal calculated_distance;
    private String route_polyline;
    private Boolean is_pet_friendly;
    private Boolean needs_child_seat;
    private Boolean needs_wheelchair_access;
    private Boolean passenger_dismissed_rating;
    private Date created_at;
    private Date accepted_at;
    private Date completed_at;
    
    // Relationships
    private User passenger;
    private User dispatcher;
    private DriverProfile driver;
    private Review review;
    private CancellationLog cancellationLog;
}

class Review {
    private UUID id;
    private Integer rating;
    private String comment;
    private Boolean is_complaint;
    private Date created_at;
}

class VirtualQueue {
    private UUID id;
    private String name;
    private Float lat;
    private Float lng;
    private Integer radius_meters;
    private Boolean is_active;
    
    // Relationships
    private List<VirtualQueueEntry> entries;
}

class VirtualQueueEntry {
    private UUID id;
    private Integer position;
    private Date joined_at;
}

class CancellationLog {
    private UUID id;
    private CancellationReason reason;
    private String note;
    private BigDecimal refund_amount;
    private Boolean refund_processed;
    private Date cancelled_at;
}