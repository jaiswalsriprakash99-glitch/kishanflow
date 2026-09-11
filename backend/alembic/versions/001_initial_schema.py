"""Initial schema revision for KisanFlow 21 tables

Revision ID: 001_initial_schema
Revises: 
Create Date: 2026-09-11 17:13:00.000000

"""
from alembic import op
import sqlalchemy as sa
from backend.app.database import Base

# revision identifiers, used by Alembic.
revision = '001_initial_schema'
down_revision = None
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Use SQLAlchemy metadata create_all for reliable migration execution
    bind = op.get_bind()
    Base.metadata.create_all(bind=bind)

def downgrade() -> None:
    bind = op.get_bind()
    Base.metadata.drop_all(bind=bind)
