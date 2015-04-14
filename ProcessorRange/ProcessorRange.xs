#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <limits.h>

#include "ppport.h"

#define VECTOR_DEFAULT_SIZE 8

//#define DEBUG_LEAKS

typedef struct _vector {
	unsigned int *values;
	unsigned int allocated_size;
	unsigned int count;
#ifdef DEBUG_LEAKS
	unsigned int id;
	unsigned int block;
#endif
} vector;

typedef struct _processor_range {
	vector *ranges;
	unsigned int processors_number;
} processor_range;

#ifdef DEBUG_LEAKS
unsigned int allocated = 0;
#endif

static vector* vector_new(unsigned int block) {
	vector *v;
	Newx(v, 1, vector);
	Newx(v->values, VECTOR_DEFAULT_SIZE, unsigned int);
	v->allocated_size = VECTOR_DEFAULT_SIZE;
	v->count = 0;
#ifdef DEBUG_LEAKS
	v->id = allocated++;
	v->block = block;
	fprintf(stderr, "allocated %d block %d\n", v->id, v->block);
#endif
	return v;
}

static vector_remove_all(vector *v) {
	v->count = 0;
}

static void vector_free(vector *v) {
	Safefree(v->values);
	Safefree(v);
#ifdef DEBUG_LEAKS
	fprintf(stderr, "freed %d block %d\n", v->id, v->block);
#endif
}

static void vector_push(vector *v, unsigned int e) {
	if (v->count == v->allocated_size) {
		unsigned int *new_values;
		Newx(new_values, 2*v->allocated_size, unsigned int);
		unsigned int i;
		for(i = 0 ; i < v->count ; i++) {
			new_values[i] = v->values[i];
		}
		Safefree(v->values);
		v->values = new_values;
		v->allocated_size *= 2;
	}
	v->values[v->count] = e;
	v->count++;
}

static inline unsigned int vector_get(vector *v, unsigned int index) {
	return v->values[index];
}

static inline unsigned int vector_get_last(vector *v) {
	return v->values[v->count -1];
}

static inline unsigned int vector_get_size(vector *v) {
	return v->count;
}

typedef processor_range* ProcessorRange;

//here for factorizing code
static ProcessorRange assign_ranges(ProcessorRange p, AV *array) {
	dTHX;
	unsigned int len = av_len(array);
	unsigned int i;
	p->processors_number = 0;
	for (i = 0 ; i <= len ; i++) {
		SV **element = av_fetch(array, i, 0);
		unsigned int value = SvNV(*element);
		vector_push(p->ranges, value);
		if (i % 2 == 0) {
			p->processors_number -= value;
		} else {
			p->processors_number += value + 1;
		}
	}
	return p;
}

//merge contiguous ranges into one
static void fix_ranges(ProcessorRange p) {
	vector *fixed_ranges = vector_new(0);
	unsigned int size = vector_get_size(p->ranges);
	unsigned int i;

	unsigned int start = vector_get(p->ranges, 0);
	vector_push(fixed_ranges, start);
	unsigned int previous_end = vector_get(p->ranges, 1);

	for(i = 2 ; i < size ; i+=2) {
		unsigned int start = vector_get(p->ranges, i);
		unsigned int end = vector_get(p->ranges, i+1);
		if (previous_end != start - 1) {
			vector_push(fixed_ranges, previous_end);
			vector_push(fixed_ranges, start);
		}
		previous_end = end;
	}
	vector_push(fixed_ranges, previous_end);
	vector_free(p->ranges);
	p->ranges = fixed_ranges;
}

MODULE = ProcessorRange		PACKAGE = ProcessorRange		

ProcessorRange
invert(ProcessorRange p, unsigned int limit)
	CODE:
	processor_range *inverted;
	Newx(inverted, 1, processor_range);
	inverted->ranges = vector_new(1);
	unsigned int last_start = 0;
	unsigned int final_end;
	unsigned int i;
	unsigned int size = vector_get_size(p->ranges);
	for(i = 0 ; i < size ; i+=2) {
		unsigned int start = vector_get(p->ranges, i);
		if (start > limit) start = limit;
		unsigned int end = vector_get(p->ranges, i+1);
		if (end > limit) end = limit;

		if (last_start != start) {
			vector_push(inverted->ranges, last_start);
			vector_push(inverted->ranges, start-1);
		}
		last_start = end + 1;
		final_end = end;
		if (end == limit) break;
	}

	if (final_end != limit) {
		vector_push(inverted->ranges, final_end+1);
		vector_push(inverted->ranges, limit);
	}
	RETVAL = inverted;
	OUTPUT:
	RETVAL

void
add(ProcessorRange range1, ProcessorRange range2)
	CODE:
	processor_range *ranges[2];
	ranges[0] = range1;
	ranges[1] = range2;
	range1->processors_number = 0;
	unsigned int inside_segments = 0;
	unsigned int starting_point; //starting point of range when iterating building them
	vector *result = vector_new(2);
	unsigned int indices[2] = { 0, 0 };
	unsigned int limits[2];
	unsigned int i;
	for (i = 0 ; i < 2 ; i++) limits[i] = vector_get_size(ranges[i]->ranges);
	while((indices[0] < limits[0]) || (indices[1] < limits[1])) {
		unsigned int x[2];
		for (i = 0 ; i < 2 ; i++) {
			if (indices[i] < limits[i]) {
				x[i] = vector_get(ranges[i]->ranges, indices[i]);
			} else {
				x[i] = UINT_MAX;
			}
		}
		unsigned int advancing_range;
		if (x[0] < x[1]) {
			advancing_range = 0;
		} else if (x[0] > x[1]) {
			advancing_range = 1;
		} else if (indices[1] % 2 == 0) {
			advancing_range = 1;
		} else {
			advancing_range = 0;
		}

		unsigned int event_type = indices[advancing_range] % 2;
		if (event_type == 0) {
			//start
			inside_segments++;
			if (inside_segments == 1) {
				starting_point = x[advancing_range];
			}
		} else {
			//end
			if (inside_segments == 1) {
				vector_push(result, starting_point);
				unsigned int end_point = x[advancing_range];
				vector_push(result, end_point);
				ranges[0]->processors_number += end_point - starting_point + 1;
			}
			inside_segments--;
		}
		indices[advancing_range]++;
	}
	vector_free(range1->ranges);
	range1->ranges = result;
	fix_ranges(range1);

void
intersection(ProcessorRange range1, ProcessorRange range2)
	CODE:
	processor_range *ranges[2];
	ranges[0] = range1;
	ranges[1] = range2;
	range1->processors_number = 0;
	unsigned int inside_segments = 0;
	unsigned int starting_point; //starting point of range when iterating building them
	vector *result = vector_new(3);
	unsigned int indices[2] = { 0, 0 };
	unsigned int limits[2];
	unsigned int i;
	for (i = 0 ; i < 2 ; i++) limits[i] = vector_get_size(ranges[i]->ranges);

	while((indices[0] < limits[0]) && (indices[1] < limits[1])) {
		unsigned int x[2];
		for (i = 0 ; i < 2 ; i++) x[i] = vector_get(ranges[i]->ranges, indices[i]);

		unsigned int advancing_range;
		if (x[0] < x[1]) {
			advancing_range = 0;
		} else if (x[0] > x[1]) {
			advancing_range = 1;
		} else if (indices[1] % 2 == 0) {
			advancing_range = 1;
		} else {
			advancing_range = 0;
		}

		unsigned int event_type = indices[advancing_range] % 2;
		if (event_type == 0) {
			//start
			inside_segments++;
			if (inside_segments == 2) {
				starting_point = x[advancing_range];
			}
		} else {
			//end
			if (inside_segments == 2) {
				vector_push(result, starting_point);
				unsigned int end_point = x[advancing_range];
				vector_push(result, end_point);
				ranges[0]->processors_number += end_point - starting_point + 1;
			}
			inside_segments--;
		}
		indices[advancing_range]++;
	}
	vector_free(range1->ranges);
	range1->ranges = result;

void
ranges_loop(ProcessorRange range, SV *subroutine)
	CODE:
	unsigned int i;
	unsigned int size = vector_get_size(range->ranges);
	for (i = 0 ; i < size ; i+=2) {
		unsigned int start = vector_get(range->ranges, i);
		unsigned int end = vector_get(range->ranges, i+1);
		int count;
		dSP;
		ENTER;
		SAVETMPS;
		PUSHMARK(SP);
		XPUSHs(sv_2mortal(newSVnv(start)));
		XPUSHs(sv_2mortal(newSVnv(end)));
		PUTBACK;
		count = call_sv(subroutine, G_SCALAR);
		SPAGAIN;
		if (count != 1) {
			fprintf(stderr, "missing return value\n");
		}
		int status = POPi;
		PUTBACK;
		FREETMPS;
		LEAVE;
		if (status == 0) return;
	}

unsigned int
is_empty(ProcessorRange p)
	CODE:
	RETVAL = (p->processors_number == 0);
	OUTPUT:
	RETVAL

unsigned int
size(ProcessorRange p)
	CODE:
	RETVAL = p->processors_number;
	OUTPUT:
	RETVAL

void
remove_all(ProcessorRange p)
	CODE:
	vector_remove_all(p->ranges);
	p->processors_number = 0;

ProcessorRange
affect_ranges(ProcessorRange p, AV *array)
	CODE:
	vector_remove_all(p->ranges);
	RETVAL = assign_ranges(p, array);
	OUTPUT:
	RETVAL

ProcessorRange
new_range(AV *array)
	CODE:
	processor_range *p;
	Newx(p, 1, processor_range);
	p->ranges = vector_new(4);
	RETVAL = assign_ranges(p, array);
	OUTPUT:
	RETVAL

ProcessorRange
copy_range(ProcessorRange original)
	CODE:
	processor_range *p;
	Newx(p, 1, processor_range);
	p->ranges = vector_new(5);
	unsigned int size = vector_get_size(original->ranges);
	unsigned int i;
	p->processors_number = 0;
	for(i = 0 ; i < size ; i++) {
		unsigned int value = vector_get(original->ranges, i);
		vector_push(p->ranges, value);
		//TODO : this code is duplicated
		if (i % 2 == 0) {
			p->processors_number -= value;
		} else {
			p->processors_number += value + 1;
		}
	}
	RETVAL = p;
	OUTPUT:
	RETVAL

void free_allocated_memory(ProcessorRange self)
	CODE:
	vector_free(self->ranges);

unsigned int
get_last(ProcessorRange p)
	CODE:
	RETVAL = vector_get_last(p->ranges);
	OUTPUT:
	RETVAL

