from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from backend.app.database import get_db
from backend.app.routers import auth, farmer, centres, bookings, queue, predictions, weather, staff, pacs, admin, procurement, payment
from backend.app.ws import ws_router

app = FastAPI(
    title="KissanFlow Backend API",
    description="Smart Queue Management, Procurement, AI Prediction & Dynamic Notification System",
    version="1.0.0"
)

app.include_router(auth.router)
app.include_router(farmer.router)
app.include_router(centres.router)
app.include_router(bookings.router)
app.include_router(queue.router)
app.include_router(predictions.router)
app.include_router(weather.router)
app.include_router(staff.router)
app.include_router(pacs.router)
app.include_router(admin.router)
app.include_router(procurement.router)
app.include_router(payment.router)
app.include_router(ws_router)

@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ok", "database": "connected"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Database connectivity failure: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.app.main:app", host="0.0.0.0", port=8000, reload=True)
